param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$EndpointCredential
)

[array]$tests = @(
    @{
        'Name' = 'Con connect to the endpoint with the provided credentials'
        'Command' = {
            try {
                Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock {1} -ErrorAction Stop
                $true
            } catch {
                $false
            }
        }
    },
    @{
        'Name' = 'The user is an admin on the endpoint'
        'Command' = {
            ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
    }
)

[array]$passedTests = foreach ($test in $tests) {
    $result = & $test.Command
    if (-not $result) {
        Write-Error -Message "The test [$($test.Name)] failed."
    } else {
        1
    }
}

if ($passedTests.Count -eq $tests.Count) {
    Write-Host "All tests have passed. You're good to go!" -ForegroundColor Green
} else {
    Write-Host "Some tests failed. Please check the errors above." -ForegroundColor Red
}