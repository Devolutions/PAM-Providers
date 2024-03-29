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
    [ValidateSet('yes','')]
    [string]$RestartService
)

# Output the script parameters and the current user running the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]"

#region Functions
# Function to create a new PSCredential object
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create a new PSCredential object using the provided EndpointUserName and EndpointPassword
$credential = newCredential $EndpointUserName $EndpointPassword

# Define a script block to be executed remotely on the Windows server
$scriptBlock = {

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

    function GetUserUPN ($UserPattern) {
    
        # Extract username and domain from the input pattern
        if ($UserPattern -match '^(.+)@(.+)$') {
            $username = $Matches[1]
            $domain = $Matches[2]
        } elseif ($UserPattern -match '^(.+)\\(.+)$') {
            $domain = $Matches[1]
            $username = $Matches[2]
        } else {
            $username = $UserPattern
            $domain = $null
        }
    
        # If domain is not an FQDN or is missing, get the current domain using WMI
        if (-not $domain -or $domain -notmatch '\.') {
            $domain = (Get-CimInstance -Class Win32_ComputerSystem).Domain
        }
    
        # Return the UPN
        "$username@$domain"
    }
    #endregion

    $ErrorActionPreference = 'Stop'

    ## Assigning to variables inside the scriptblock allows mocking of args with Pester
    $username = GetUserUPN($args[0])
    $pw = $args[1]
    $serviceNames = $args[2]
    $restartService = $args[3]

    if (-not $serviceNames) {
        $cimFilter = "StartName='$username'"
    } else {
        $cimFilter = "(Name='{0}') AND StartName='{1}'" -f ($serviceNames -join "' OR Name='"), $username
    }
    $cimFilter = $cimFilter.replace('\', '\\')

    $serviceInstances = Get-CimInstance -ClassName Win32_Service -Filter $cimFilter
    if ($serviceNames -and ($notFoundServices = $serviceNames.where({ $_ -notin @($serviceInstances).Name }))) {
        Write-Output -InputObject ("The following services could not be found on host [{0}] running as [{1}]: {2}. Skipping these services." -f (hostname), $username, ($notFoundServices -join ','))
    } elseif (-not $serviceInstances) {
        throw "No services found on [{0}] running as [{1}] could be found." -f (hostname), $username
    }

    $results = foreach ($servInst in $serviceInstances) {
        try {
            $updateResult = updateServiceUserPassword -ServiceInstance $servInst -Username $username -Password $pw
            if ($updateResult.ReturnValue -ne 0) {
                throw "Password update for service [{0}] failed with return value [{1}]" -f $servInst.Name, $updateResult.ReturnValue
            }
            if ($restartService -eq 'yes' -and $servInst.State -eq 'Running') {
                Restart-Service -Name $servInst.Name
            }
            $true
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    @($results).Count -eq @($serviceInstances).Count
}

## To process multiple services at once. This approach must be done because DVLS will not allow you to pass an array
## of strings via a parameter.
$serviceNames = $ServiceName -split ','

$invParams = @{
    ComputerName = $Endpoint
    ScriptBlock  = $scriptBlock
    Credential   = $credential
    ArgumentList = $AccountUserName, $NewPassword, $serviceNames, $RestartService
}
Invoke-Command @invParams