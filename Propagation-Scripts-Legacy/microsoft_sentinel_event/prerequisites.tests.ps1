#requires -Version 7
<#
.SYNOPSIS
This script tests prerequisites for the Microsoft Sentinel Password Change Notification Propagation Script.
.DESCRIPTION
Verifies that all necessary prerequisites are met to run the Microsoft Sentinel propagation script.
.PARAMETER WorkspaceId
The ID of your Microsoft Sentinel workspace.
.PARAMETER WorkspaceKey
The Primary Key of your Microsoft Sentinel workspace.
.EXAMPLE
PS> .\prerequisites.tests.ps1 -WorkspaceId "12345678-1234-1234-1234-123456789012" -WorkspaceKey "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789=="
This example runs the prerequisite checks for the Microsoft Sentinel propagation script.
#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceKey
)

$ErrorActionPreference = 'Stop'

function Send-LogToSentinel {
    param (
        [string]$WorkspaceId,
        [string]$LogName,
        [string]$signature,
        [string]$rfc1123date,
        [string]$resource,
        [string]$method,
        [string]$contentType,
        [string]$logEntry
    )

    $uri = "https://${WorkspaceId}.ods.opinsights.azure.com${resource}?api-version=2016-04-01"
    Write-Debug "URI: $uri"

    $headers = @{
        "Authorization"        = $signature
        "Log-Type"             = $LogName
        "x-ms-date"            = $rfc1123date
        "time-generated-field" = "TimeGenerated"
    }
    Write-Debug "Headers: $($headers | ConvertTo-Json -Compress)"

    $params = @{
        Uri                  = $uri
        Method               = $method
        ContentType          = $contentType
        Headers              = $headers
        Body                 = $logEntry
        UseBasicParsing      = $true
        StatusCodeVariable   = 'statusCode'
    }
    $response = Invoke-RestMethod @params
    Write-Debug "Status Code: $statusCode"
    if ($statusCode -ne 200) {
        [pscustomobject]@{
            Result       = $false
            ErrorMessage = "Failed to send log to Sentinel. Status code: $statusCode, Response: $response"
        }
    } else {
        [pscustomobject]@{
            Result       = $true
            ErrorMessage = $null
        }
    }
}

function New-Signature {
    param (
        [string]$WorkspaceId,
        [string]$WorkspaceKey,
        [string]$LogEntry
    )

    # Prepare the data to send
    $currentTime = [DateTime]::UtcNow.ToString("o")
    Write-Debug "Current time: $currentTime"

    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    Write-Debug "RFC1123 date: $rfc1123date"

    $contentLength = ([System.Text.Encoding]::UTF8.GetBytes($LogEntry)).Length
    Write-Debug "Content length: $contentLength"

    $xHeaders = "x-ms-date:$rfc1123date"
    $stringToHash = "$method`n$contentLength`n$contentType`n$xHeaders`n$resource"
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($WorkspaceKey)
    $hmacsha256 = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha256.Key = $keyBytes
    $calculatedHash = $hmacsha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    
    # Return a hashtable with all the necessary information
    @{
        Signature = "SharedKey ${WorkspaceId}:${encodedHash}"
        RFC1123Date = $rfc1123date
        Method = $method
        ContentType = $contentType
        Resource = $resource
        ContentLength = $contentLength
    }
}

[array]$tests = @(
    @{
        'Name'           = 'PowerShell version is 7.0 or later'
        'Command'        = {
            try {
                if ($PSVersionTable.PSVersion.Major -ge 7) {
                    [pscustomobject]@{
                        Result       = $true
                        ErrorMessage = $null
                    }
                } else {
                    throw "PowerShell version is $($PSVersionTable.PSVersion). Version 7.0 or later is required."
                }
            } catch {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = "Error checking PowerShell version: $_"
                }
            }
        }
        'ParametersUsed' = @()
    },
    @{
        'Name'           = 'Can connect to Microsoft Sentinel workspace'
        'Command'        = {
            try {

                $logEntry = @{
                    TimeGenerated = [DateTime]::UtcNow.ToString("o")
                    AccountName   = $UserName
                    Event         = "Password Changed"
                } | ConvertTo-Json

                $signatureInfo = New-Signature -WorkspaceId $WorkspaceId -WorkspaceKey $WorkspaceKey -LogEntry $logEntry

                
                $response = Send-LogToSentinel -WorkspaceId $WorkspaceId -LogName "TestLog" -signature $signatureInfo.Signature `
                    -rfc1123date $signatureInfo.RFC1123Date -resource $signatureInfo.Resource -method $signatureInfo.Method `
                    -contentType $signatureInfo.ContentType -logEntry $logEntry

                if ($response.Result -eq $true) {
                    [pscustomobject]@{
                        Result       = $true
                        ErrorMessage = $null
                    }
                } else {
                    throw "Unexpected response from Microsoft Sentinel: $($response.ErrorMessage)"
                }
            } catch {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = "Error connecting to Microsoft Sentinel: $_"
                }
            }
        }
        'ParametersUsed' = @('WorkspaceId', 'WorkspaceKey', 'UserName')
    }
)

$applicableTests = $tests.where({ $paramsUsed = $_.ParametersUsed; $_.ParametersUsed.Count -eq 0 -or $PSBoundParameters.Keys.where({ $_ -in $paramsUsed }) })

[array]$passedTests = foreach ($test in $applicableTests) {
    $result = & $test.Command
    if (-not $result.Result) {
        Write-Host "The test [$($test.Name)] failed: [$($result.ErrorMessage)]" -ForegroundColor Red
    } else {
        Write-Host "The test [$($test.Name)] passed." -ForegroundColor Green
        1
    }
}

if ($passedTests.Count -eq $applicableTests.Count) {
    Write-Host "All tests have passed. You're good to go!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Please review the errors and address them before running the propagation script." -ForegroundColor Yellow
}