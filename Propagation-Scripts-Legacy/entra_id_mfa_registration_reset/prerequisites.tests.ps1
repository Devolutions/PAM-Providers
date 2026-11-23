#requires -Version 7.0
<#
.SYNOPSIS
Tests prerequisites for the Entra ID MFA reset propagation script.

.DESCRIPTION
This script checks the necessary prerequisites for running the Entra ID MFA reset propagation script.
It verifies PowerShell version, required modules, and tests the connection to Microsoft Graph API.

.PARAMETER TenantId
The ID of your Entra ID tenant.

.PARAMETER ClientId
The client ID of the application registered in Entra ID for authentication.

.PARAMETER ClientSecret
The client secret of the application registered in Entra ID for authentication.

.EXAMPLE
PS> $clientSecret = ConvertTo-SecureString "YourClientSecret" -AsPlainText -Force
PS> .\prerequisites.tests.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret $clientSecret

This example runs the prerequisite checks for the Entra ID MFA reset propagation script.

#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$ClientSecret
)

$ErrorActionPreference = 'Stop'

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

function Test-GraphApiConnection {
    param (
        [string]$TenantId,
        [string]$ClientId,
        [securestring]$ClientSecret
    )

    try {
        $tokenResponse = Get-GraphApiToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
        $headers = @{
            "Authorization" = "Bearer $($tokenResponse.access_token)"
            "Content-Type"  = "application/json"
        }

        $graphResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users?`$top=1" -Headers $headers -Method Get
        if ($graphResponse.value) {
            $true
        }
    }
    catch {
        $false
    }
}

[array]$tests = @(
    @{
        'Name'    = 'PowerShell 7.0 or higher is installed'
        'Command' = {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                [pscustomobject]@{
                    Result       = $true
                    ErrorMessage = $null
                }
            }
            else {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = "PowerShell version 7.0 or higher is required. Current version: $($PSVersionTable.PSVersion)"
                }
            }
        }
    },
    @{
        'Name'    = 'Microsoft Graph API connection is successful'
        'Command' = {
            if (Test-GraphApiConnection -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret) {
                [pscustomobject]@{
                    Result       = $true
                    ErrorMessage = $null
                }
            }
            else {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = "Failed to connect to Microsoft Graph API. Please check your credentials and permissions."
                }
            }
        }
    }
)

[array]$passedTests = foreach ($test in $tests) {
    $result = & $test.Command
    if (-not $result.Result) {
        Write-Host "The test [$($test.Name)] failed: [$($result.ErrorMessage)]" -ForegroundColor Red
    }
    else {
        Write-Host "The test [$($test.Name)] passed." -ForegroundColor Green
        1
    }
}

if ($passedTests.Count -eq $tests.Count) {
    Write-Host "`nAll prerequisites are met. You're good to go!" -ForegroundColor Green
}
else {
    Write-Host "`nSome prerequisites are not met. Please address the issues above before running the main script." -ForegroundColor Yellow
}