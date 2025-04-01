[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EndpointUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$EndpointPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(?:(?:([^@\\]+)@|([^@\\]+)\\)?([^@\\]+))?$')]
    [string]$AccountUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$ServiceName,

    [Parameter()]
    [ValidateSet('yes', '')]
    [string]$RestartService
)

function Write-DvlsHost($Message) {
    Write-Output $Message
}

Write-DvlsHost "Starting script execution with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]"

#region Functions
# Function to create a new PSCredential object
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create a new PSCredential object using the provided EndpointUserName and EndpointPassword
Write-DvlsHost "Creating new credential for user: $EndpointUserName"
$credential = newCredential $EndpointUserName $EndpointPassword

# Get the definition of the Write-DvlsHost function to pass to remote session
$writeDvlsHostDef = "function Write-DvlsHost { ${function:Write-DvlsHost} }"

# Define a script block to be executed remotely on the Windows server
$scriptBlock = {
    param(
        [string]$AccountUserName,
        [securestring]$NewPassword,
        [string[]]$ServiceNames,
        [string]$RestartService,
        [string]$WriteDvlsHostDef
    )

    try {
        # Create the Write-DvlsHost function in the remote session
        . ([ScriptBlock]::Create($WriteDvlsHostDef))

        #region functions
        # Function to decrypt a secure string password
        function decryptPassword {
            param(
                [securestring]$Password
            )
            try {
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            } finally {
                ## Clear the decrypted password from memory
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }

        function updateServiceUserPassword($ServiceInstance, [string]$UserName, [securestring]$Password) {
            Invoke-CimMethod -InputObject $ServiceInstance -MethodName Change -Arguments @{
                StartName     = $UserName
                StartPassword = decryptPassword($Password)
            }
        }

        function ConvertToUserUpn ($UserName) {

            function isLocalUser ($UserName) {
                # Validate local username format and length (max 20 chars)
                $UserName -match '^([a-zA-Z0-9_]{1,20}|\.\\[a-zA-Z0-9_]{1,20})$'
            }

            function isUpn ($UserName) {
                $UserName -match '^(.+)@(.+)$'
            }

            if (isUpn $UserName) {
                $UserName
            } elseif (isLocalUser $UserName) {
                $UserName -replace '^(?!\.\\)', '.\'
            } else {
                $username = $null
                $domain = $null

                # Extract username and domain from domain\username format
                if ($UserName -match '^(.+)\\(.+)$') {
                    $domain = $Matches[1]
                    $username = $Matches[2]
                }

                # Validate extracted values and use DomainInput if domain is not found
                if (-not $username) {
                    throw "Could not determine username from user name [$UserName]"
                }

                if (-not $domain) {
                    $domain = (Get-CimInstance -Class Win32_ComputerSystem).Domain
                }

                "$username@$domain"
            }
        }
        #endregion

        $ErrorActionPreference = 'Stop'

        $username = ConvertToUserUpn $AccountUserName
        $pw = $NewPassword

        Write-DvlsHost "Processing services for user: $username"
        Write-DvlsHost "Service names to process: $($ServiceNames -join ',')"
        Write-DvlsHost "Restart service flag: $RestartService"

        if (-not $ServiceNames) {
            $cimFilter = "StartName='$username'"
        } else {
            $cimFilter = "(Name='{0}') AND StartName='{1}'" -f ($ServiceNames -join "' OR Name='"), $username
        }
        $cimFilter = $cimFilter.replace('\', '\\')
        Write-DvlsHost "Using CIM filter: $cimFilter"

        $serviceInstances = Get-CimInstance -ClassName Win32_Service -Filter $cimFilter
        if ($ServiceNames -and ($notFoundServices = $ServiceNames.where({ $_ -notin @($serviceInstances).Name }))) {
            Write-DvlsHost "The following services could not be found on host [{0}] running as [{1}]: {2}. Skipping these services." -f (hostname), $username, ($notFoundServices -join ',')
        } elseif (-not $serviceInstances) {
            throw "No services found on [{0}] running as [{1}] could be found." -f (hostname), $username
        }

        Write-DvlsHost "Found $(@($serviceInstances).Count) services to process"

        $successResults = foreach ($servInst in $serviceInstances) {
            try {
                $updateResult = updateServiceUserPassword -ServiceInstance $servInst -Username $username -Password $pw
                if ($updateResult.ReturnValue -ne 0) {
                    throw "Password update for service [{0}] failed with return value [{1}]" -f $servInst.Name, $updateResult.ReturnValue
                }
                $servInst.Name
            } catch {
                throw $_
            }
        }
        Write-DvlsHost "Successfully updated passwords for the following services: $($successResults -join ',')"

        # Restart services after all password updates. This prevents issues like when mulitple services need to be updated
        # that are running and need to be restarted but depend on one another
        if ($RestartService -eq 'yes') {
            Write-DvlsHost "Restarting running services"
            $serviceInstances | Where-Object { $_.State -eq 'Running' } | ForEach-Object {
                Write-DvlsHost "Restarting service: $($_.Name)"
                ## -Force ensures all dependent services are also restarted
                Restart-Service -Name $_.Name -Force
            }
        }

        if (@($successResults).Count -ne @($serviceInstances).Count) {
            throw "Failed to update passwords for the following services: $($serviceInstances.Name -join ',')"
        }
    } catch {
        Write-DvlsHost "Error: $($_.Exception.Message)"
        throw $_.Exception.Message
    }
}

## To process multiple services at once. This approach must be done because DVLS will not allow you to pass an array
## of strings via a parameter.
$serviceNames = $ServiceName -split ','
Write-DvlsHost "Split service names into array: $($serviceNames -join ',')"

if ($Endpoint -in ($Env:COMPUTERNAME, 'localhost', '127.0.0.1')) {
    Write-DvlsHost "Executing script block locally"
    & $scriptBlock -AccountUserName $AccountUserName -NewPassword $NewPassword -ServiceNames $serviceNames -RestartService $RestartService -WriteDvlsHostDef $writeDvlsHostDef
} else {
    Write-DvlsHost "Executing script block remotely on endpoint: $Endpoint"
    $invParams = @{
        ComputerName = $Endpoint
        ScriptBlock  = $scriptBlock
        Credential   = $credential
        ArgumentList = $AccountUserName, $NewPassword, $serviceNames, $RestartService, $writeDvlsHostDef
    }
    try {
        Invoke-Command @invParams
    } catch {
        Write-DvlsHost "Error: $($_.Exception.Message)"
        throw $_.Exception.Message
    }
}