param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ZapierWebhookUrl
)

[array]$tests = @(
    @{
        'Name' = 'Con successfully call the webhook'
        'Command' = {
            try {
                Invoke-RestMethod -Uri $ZapierWebhookUrl -Body @{ 'credential' = 'just testing'; 'message' = 'some message'} -ErrorAction Stop
                $true
            } catch {
                $false
            }
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