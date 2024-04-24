#requires -Version 7

<#
.SYNOPSIS
Updates the password for a specified service account and optionally restarts the service on a remote system.

.DESCRIPTION
This script updates the service account password on a specified endpoint. It supports both domain and local user accounts and can handle multiple services. If specified, it can also restart the services after updating the password.

.PARAMETER Endpoint
Specifies the target endpoint where the service(s) are running. This should be the hostname or IP address of the remote system.

.PARAMETER EndpointUserName
Specifies the username used to authenticate against the endpoint. This should be an account with permissions to modify service settings.

.PARAMETER EndpointPassword
Specifies the password for the EndpointUserName as a secure string.

.PARAMETER AccountUserName
Specifies the service account username whose password needs updating. This parameter must be a flat username without domain information.

.PARAMETER NewPassword
Specifies the new password for the service account as a secure string.

.PARAMETER AccountUserNameDomain
Optional. Specifies the domain of the service account in FQDN format if the account is a domain account.

.PARAMETER ServiceName
Optional. Specifies the name of the service that needs the service account password updated. If not provided, all services running under the specified account will be updated.

.PARAMETER RestartService
Optional. Specifies whether to restart the service after updating the password. Acceptable values are 'yes' to restart the service, or an empty string to leave the service running without restarting.

.EXAMPLE
PS C:\> .\script.ps1 -Endpoint 'server01' -EndpointUserName 'administrator' -EndpointPassword (ConvertTo-SecureString 'Passw0rd!' -AsPlainText -Force) -AccountUserName 'svc_account' -NewPassword (ConvertTo-SecureString 'N3wPassw0rd!' -AsPlainText -Force) -AccountUserNameDomain 'domain.local' -ServiceName 'MyService' -RestartService 'yes'

This example updates the password for the 'svc_account' user on the 'domain.local' domain, specifically for 'MyService' on 'server01', and restarts the service after the update.

.NOTES
This script requires PowerShell Remoting to be enabled and configured on the target endpoint. Ensure credentials provided have the necessary administrative rights on the remote system.
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
    [ValidatePattern(
        '^\w+$',
        ErrorMessage = 'You must provide the AccountUserName parameter as a flat name like "user"; not domain\user, et al. To specify a domain, use the AccountUserNameDomain parameter.'
    )]
    [string]$AccountUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [ValidatePattern(
        '^\w+\.\w+$',
        ErrorMessage = 'When using the AccountUserNameDomain parameter, you must provide the domain as an FQDN (domain.local)'
    )]
    [string]$AccountUserNameDomain,

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

    function updateServiceUserPassword {
        param(
            $ServiceInstance,
            [string]$UserName,
            [securestring]$Password
        )    
    
        Invoke-CimMethod -InputObject $ServiceInstance -MethodName Change -Arguments @{
            StartName     = $UserName
            StartPassword = decryptPassword($Password)
        }
    }

    function GetServiceAccountNames {
        param(
            $UserName,
            $Domain
        )

        if (!$Domain) {
            ## local account
            @(
                "$($Domain)\$($Username)" ## domain\user
            )
        } else {
            ## Domain account with domain as FQDN
            @(
                "$($Username)@$($Domain)", ## user@domain.local
                "$($Domain.split('.')[0])\$($Username)" ## domain\user
            )
        }
    }

    function ValidateUserAccountPassword {
        [CmdletBinding()]
        param(
            [string]$UserName,
            [string]$Domain,
            [securestring]$Password
        )

        try {
            Add-Type -AssemblyName System.DirectoryServices.AccountManagement

            if ($Domain) {
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)
            } else {
                $context = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Machine)
            }
        
            $context.ValidateCredentials($UserName, (decryptPassword($Password)))
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
    $userName = $args[0]
    $userDomain = $args[1]
    $pw = $args[2]
    $serviceNames = $args[3]
    $restartService = $args[4]

    ## Ensure the password is valid
    $validatePwResult = ValidateUserAccountPassword -UserName $userName -Domain $userDomain -Password $pw
    if (!$validatePwResult) {
        throw "The password for user account [$($UserName)] is invalid. Did you mean to provide a domain account? If so, use the AccountUserNameDomain parameter."
    }

    $serviceAccountNames = GetServiceAccountNames -UserName $userName -Domain $userDomain
    $startNameCimQuery = "(StartName = '{0}')" -f ($serviceAccountNames -join "' OR StartName = '") ## (StartName = 'user@domain.local' OR StartName = 'domain\user')

    if (-not $serviceNames) {
        $cimFilter = $startNameCimQuery
    } else {
        $cimFilter = "(Name='{0}') AND {1}" -f ($serviceNames -join "' OR Name='"), $startNameCimQuery
    }
    $cimFilter = $cimFilter.replace('\', '\\')
    
    $serviceInstances = Get-CimInstance -ClassName Win32_Service -Filter $cimFilter
    if (-not $serviceInstances) {
        throw "No services found on [{0}] running as [{1}] could be found." -f (hostname), $serviceAccountNames[0]
    }

    $results = foreach ($servInst in $serviceInstances) {
        try {
            $updateResult = updateServiceUserPassword -ServiceInstance $servInst -Username $serviceAccountNames[0] -Password $pw
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
    ArgumentList = $AccountUserName, $AccountUserNameDomain, $NewPassword, $serviceNames, $RestartService
}
Invoke-Command @invParams