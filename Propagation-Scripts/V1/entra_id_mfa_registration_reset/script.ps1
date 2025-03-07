<#
.SYNOPSIS
Resets multi-factor authentication methods for an Entra ID user.

.DESCRIPTION
This script removes all authentication methods except password for a specified Entra ID (formerly Azure AD) user. It's 
designed to work with organizational policies that automatically re-add authentication methods.

The script connects to Microsoft Graph API, retrieves the user's authentication methods, and removes all non-password methods.

.PARAMETER UserName
The username of the Entra ID user (without domain).

.PARAMETER NewPassword
The new password for the user. This is not used in the current script but is a required parameter for propagation scripts.

.PARAMETER TenantId
The ID of your Entra ID tenant.

.PARAMETER ClientId
The client ID of the application registered in Entra ID for authentication.

.PARAMETER ClientSecret
The client secret of the application registered in Entra ID for authentication.

.PARAMETER TenantDomain
The domain name of your Entra ID tenant.

.EXAMPLE
PS> $clientSecret = ConvertTo-SecureString "YourClientSecret" -AsPlainText -Force
PS> .\script.ps1 -UserName "johndoe" -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret $clientSecret -TenantDomain "yourdomain.com"

This example resets the MFA methods for the user "johndoe" in the specified Entra ID tenant.

.NOTES
Prerequisites:
- The application must have the following Microsoft Graph API permissions:
  * User.ReadBasic.All
  * UserAuthenticationMethod.ReadWrite.All

Ensure these permissions are granted in the Azure portal for the application used.

For more information on authentication method management, see:
https://learn.microsoft.com/en-us/graph/api/resources/authenticationmethods-overview?view=graph-rest-1.0#require-re-register-multifactor-authentication

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter()]
    [securestring]$NewPassword,

    [Parameter(Mandatory)]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [securestring]$ClientSecret,

    [Parameter(Mandatory)]
    [string]$TenantDomain
)

$ErrorActionPreference = 'Stop'

function decryptSecureString {
    param(
        [securestring]$SecureString
    )
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Get-GraphApiToken {
    param ()
    $body = @{
        grant_type    = "client_credentials"
        scope         = "https://graph.microsoft.com/.default"
        client_id     = $ClientId
        client_secret = (decryptSecureString $ClientSecret)
    }
    Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
}

function Invoke-GraphApiCall {
    param (
        [string]$Uri,
        [string]$Method,
        [object]$Body
    )
    
    $params = @{
        Uri     = $Uri
        Method  = $Method
        Headers = $script:headers
    }
    
    if ($Body) {
        $params.Body = $Body | ConvertTo-Json
    }
    
    Invoke-RestMethod @params
}

function Get-UserAuthenticationMethod {
    param (
        [string]$UserId
    )
    $methodsUri = "https://graph.microsoft.com/v1.0/users/$UserId/authentication/methods"
    $methods = Invoke-GraphApiCall -Uri $methodsUri -Method 'GET'
    $methods.value

    ## where .password is not null???
}

function Get-EntraIdUserId {
    param (
        [string]$UserPrincipalName
    )

    $uri = "https://graph.microsoft.com/v1.0/users?$filter=userPrincipalName eq '$UserPrincipalName'"
    $response = Invoke-GraphApiCall -Uri $uri -Method 'GET'

    if ($response.value -and $response.value.Count -eq 1) {
        $response.value[0].id
    }
}


function Remove-AuthenticationMethod {
    param (
        [string]$UserId,
        [string]$MethodId,
        [string]$AuthType
    )

    $deleteUri = "https://graph.microsoft.com/v1.0/users/$UserId/authentication/$AuthType/$MethodId"
    Invoke-GraphApiCall -Uri $deleteUri -Method 'DELETE'
}

try {
    $tokenResponse = Get-GraphApiToken
    $script:headers = @{
        "Authorization" = "Bearer $($tokenResponse.access_token)"
        "Content-Type"  = "application/json"
    }

    $userPrincipalName = "$UserName@$TenantDomain"
    Write-Debug "UserPrincipalName: $userPrincipalName"
    if (-not ($userId = Get-EntraIdUserId -UserPrincipalName $userPrincipalName)) {
        throw "User not found: $UserPrincipalName"
    } else {
        Write-Debug "User found: $userId"
    }

    $enabledAuthMethods = Get-UserAuthenticationMethod -UserId $userId

    $mfaAuthMethods = $enabledAuthMethods | Where-Object -Property '@odata.type' -ne '#microsoft.graph.passwordAuthenticationMethod'
    if (-not $mfaAuthMethods) {
        Write-Debug "No MFA methods to reset for user: $userPrincipalName"
    } else {
        $authTypeToApiEndpointMap = @{
            '#microsoft.graph.phoneAuthenticationMethod' = 'phone'
            '#microsoft.graph.fido2AuthenticationMethod' = 'fido2'
            '#microsoft.graph.emailAuthenticationMethod' = 'email'
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' = 'microsoftAuthenticator'
        }
    
        foreach ($authMethod in $mfaAuthMethods) {
            $authType = '{0}Methods' -f $authTypeToApiEndpointMap[$authMethod.'@odata.type']
            Write-Debug "Removing auth method: $authMethod"
            Remove-AuthenticationMethod -UserId $userId -MethodId $authMethod.id -AuthType $authType
        }
    }
    $true
} catch {
    $false
    Write-Error "An error occurred: $_"  
}