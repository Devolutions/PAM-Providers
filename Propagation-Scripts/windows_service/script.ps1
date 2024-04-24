<#
.SYNOPSIS
This script updates the password of a service account on a specified endpoint and optionally restarts the service.

.DESCRIPTION
The script connects to a remote server using provided credentials and changes the password stored for the service(s). 
It supports validation of the new password against the account and can restart the services upon successful password update.

.PARAMETER Endpoint
Specifies the target endpoint (server) where the service account password needs to be updated.

.PARAMETER EndpointUserName
Specifies the username used to authenticate to the endpoint. This should have adequate permissions to manage services and 
accounts on the target server.

.PARAMETER EndpointPassword
Specifies the secure password for the EndpointUserName. This must be a SecureString to ensure security during transmission.

.PARAMETER AccountUserName
Specifies the service account username whose password needs updating. It can be in 'user@domain', 'domain\user', or 'user' format.

.PARAMETER NewPassword
Specifies the new password for the service account. This must be a SecureString to ensure it is handled securely.

.PARAMETER ServiceName
Optional. Specifies the service(s) associated with the account. Multiple services can be specified, separated by commas. 
If omitted, the script will attempt to update the account password for all services running under the specified account.

.PARAMETER RestartService
Optional. Specifies whether to restart the service after updating the password. Acceptable values are 'yes' or 
'' (empty string for no). Default is no restart.

.EXAMPLE
.\script.ps1 -Endpoint "Server01" -EndpointUserName "admin" -EndpointPassword (ConvertTo-SecureString "Password123" -AsPlainText -Force) -AccountUserName "serviceaccount" -NewPassword (ConvertTo-SecureString "NewPassword123" -AsPlainText -Force) -ServiceName "Service01,Service02" -RestartService "yes"

This example updates the password for 'serviceaccount' on 'Server01' for 'Service01' and 'Service02', then restarts those services.

.NOTES
Make sure that the user running this script has appropriate permissions on the remote system to manage services and user accounts.
Ensure that the network policies and firewall settings allow remote management and service manipulation commands.
#>
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

    function extractUsernameDomain ($UserPattern) {
        if ($UserPattern -match '^(.+)@(.+)$') {
            $username = $Matches[1]
            $domain = $Matches[2]
        } elseif ($UserPattern -match '^(.+)\\(.+)$') {
            $domain = $Matches[1]
            $username = $Matches[2]
        } else {
            $username = $UserPattern
            $domain = '.'
        }
        [pscustomobject]@{
            UserName = $username
            Domain   = $domain
        }
    }

    function GetServiceAccountName ($User) {
    
        if ($User.Domain -eq '.') {
            $accountName = "$($User.Domain)\$($User.Username)"
        } else {
            $fqdnDomain = (Get-CimInstance -Class Win32_ComputerSystem).Domain
            if ($fqdnDomain.split('.')[0] -ne $User.Domain) {
                throw "Could not determine the domain. Use a UPN (username@domain.local) for a more specific match."
            }
            $accountName = "$($User.Username)@$fqdnDomain"
        }

        $accountName
    }

    function ValidateUserAccountPassword {
        [CmdletBinding()]
        param(
            [pscustomobject]$User,
            [securestring]$Password
        )

        try {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement

            if ($User.Domain -ne '.') {
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $User.Domain)
            } else {
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
            }
        
            $context.ValidateCredentials($User.UserName, (decryptPassword($Password)))
        } catch {
            Write-Error "An error occurred: $_"
        } finally {
            if ($context) {
                $context.Dispose()
            }
        }
    }
    #endregion

    $ErrorActionPreference = 'Stop'

    ## Assigning to variables inside the scriptblock allows mocking of args with Pester

    $pw = $args[1]
    $serviceNames = $args[2]
    $restartService = $args[3]

    ## Get the user account in a format we can validate the password for
    $user = extractUsernameDomain $args[0]

    ## Ensure the password is valid
    $validatePwResult = ValidateUserAccountPassword -User $user -Password $pw
    if (!$validatePwResult) {
        throw "The password for user account [$($User.UserName)] is invalid."
    }

    $serviceAccountName = GetServiceAccountName($user)

    if (-not $serviceNames) {
        $cimFilter = "StartName='$serviceAccountName'"
    } else {
        $cimFilter = "(Name='{0}') AND StartName='{1}'" -f ($serviceNames -join "' OR Name='"), $serviceAccountName
    }
    $cimFilter = $cimFilter.replace('\', '\\')

    $serviceInstances = Get-CimInstance -ClassName Win32_Service -Filter $cimFilter
    if (-not $serviceInstances) {
        throw "No services found on [{0}] running as [{1}] could be found." -f (hostname), $serviceAccountName
    }

    $results = foreach ($servInst in $serviceInstances) {
        try {
            $updateResult = updateServiceUserPassword -ServiceInstance $servInst -Username $serviceAccountName -Password $pw
            if ($updateResult.ReturnValue -ne 0) {
                throw "Password update for service [{0}] failed with return value [{1}]" -f $servInst.Name, $updateResult.ReturnValue
            }
            if ($restartService -eq 'yes' -and $servInst.State -eq 'Running') {
                Restart-Service -Name $servInst.Name
            }
            $true
        } catch {
            Write-Error -Message $_.Exception.Message
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