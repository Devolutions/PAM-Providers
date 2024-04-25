#requires -Version 7
<#
.SYNOPSIS
This script tests...
.DESCRIPTION
...
.PARAMETER Endpoint
...
.PARAMETER EndpointCredential
...
.EXAMPLE
PS> $cred = Get-Credential
PS> .\prerequisites.tests.ps1 -Endpoint "sql.example.com" -EndpointCredential $cred
This example...
#>
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$EndpointCredential
)

[array]$tests = @(
    @{
        'Name'           = 'WinRM is available'
        'Command'        = {

            ## code to check stuff here to return $true added to the Result property and any error to the ErrorMessage property

            [pscustomobject]@{
                Result       = $null
                ErrorMessage = $null
            }
        }
        'ParametersUsed' = @()
    }
)

$applicableTests = $tests.where({ $paramsUsed = $_.ParametersUsed; $_.ParametersUsed.Count -gt 0 -or $PSBoundParameters.Keys.where({ $_ -in $paramsUsed }) })

[array]$passedTests = foreach ($test in $applicableTests) {
    $result = & $test.Command
    if (-not $result.Result) {
        Write-Error -Message "The test [$($test.Name)] failed: [$($result.ErrorMessage)]"
    } else {
        1
    }
}

if ($passedTests.Count -eq $applicableTests.Count) {
    Write-Host "All tests have passed. You're good to go!" -ForegroundColor Green
}