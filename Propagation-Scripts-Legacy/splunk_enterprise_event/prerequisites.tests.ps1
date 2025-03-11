#requires -Version 7.0
<#
.SYNOPSIS
This script tests the prerequisites for the Splunk password change event propagation script.

.DESCRIPTION
This script checks the following prerequisites:
1. PowerShell version is 7.0 or higher
2. Required modules are installed
3. Connectivity to the Splunk server
4. Validity of the HEC token
5. Permissions to send events to Splunk

.PARAMETER SplunkHost
The hostname or IP address of the Splunk server.

.PARAMETER HECToken
A secure string containing the HTTP Event Collector (HEC) token for authentication with Splunk.

.PARAMETER Port
The port number for the Splunk HEC. If not specified, it defaults to 8088.

.PARAMETER Protocol
The protocol to use for the connection to Splunk. Valid values are "http" or "https". If not specified, it defaults to "https".

.EXAMPLE
PS> $hecToken = ConvertTo-SecureString "YourHECTokenHere" -AsPlainText -Force
PS> .\prerequisites.tests.ps1 -SplunkHost "splunk.example.com" -HECToken $hecToken -Port 8088 -Protocol "https"

This example runs the prerequisites check for the Splunk server at "splunk.example.com" using the specified HEC token, port, and protocol.

#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SplunkHost,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$HECToken,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 8088,

    [Parameter()]
    [ValidateSet("http", "https")]
    [string]$Protocol = "https"
)

$ErrorActionPreference = 'Stop'

[array]$tests = @(
    @{
        'Name'           = 'PowerShell version is 7.0 or higher'
        'Command'        = {
            try {
                $psVersion = $PSVersionTable.PSVersion
                if ($psVersion.Major -ge 7) {
                    [pscustomobject]@{
                        Result       = $true
                        ErrorMessage = $null
                    }
                } else {
                    throw
                }
            } catch {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = "PowerShell version $($psVersion.ToString()) is not supported. Version 7.0 or higher is required."
                }
            }
        }
        'ParametersUsed' = @()
    },
    @{
        'Name'           = 'Connectivity to Splunk server'
        'Command'        = {
            try {
                $testConnection = Test-NetConnection -ComputerName $SplunkHost -Port $Port
                if ($testConnection.TcpTestSucceeded) {
                    [pscustomobject]@{
                        Result       = $true
                        ErrorMessage = $null
                    }
                } else {
                    throw "Unable to connect to Splunk server at $SplunkHost on port $Port."
                }
            } catch {
                [pscustomobject]@{
                    Result       = $false
                    ErrorMessage = $_.Exception.Message
                }
            }
        }
        'ParametersUsed' = @('SplunkHost', 'Port')
    }
)

$applicableTests = $tests.where({ $paramsUsed = $_.ParametersUsed; $_.ParametersUsed.Count -eq 0 -or $PSBoundParameters.Keys.where({ $_ -in $paramsUsed }) })

[array]$passedTests = foreach ($test in $applicableTests) {
    $result = & $test.Command
    if (-not $result.Result) {
        Write-Host "The test [$($test.Name)] failed: [$($result.ErrorMessage)]" -ForegroundColor Red
    } else {
        Write-Host "Test [$($test.Name)] passed." -ForegroundColor Green
        1
    }
}

if ($passedTests.Count -eq $applicableTests.Count) {
    Write-Host "All tests have passed. The Splunk password change event propagation script should work correctly." -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Please address the issues before running the Splunk password change event propagation script." -ForegroundColor Yellow
}