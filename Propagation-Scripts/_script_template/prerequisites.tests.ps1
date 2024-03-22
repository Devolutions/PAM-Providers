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
        'Name'    = 'WinRM is available'
        'Command' = { Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock { 1 } }
    }
    @{
        'Name' = 'User has admin privileges on target server'
        'Command'                                    = {
            Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock {
                $currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                $principal = New-Object System.Security.Principal.WindowsPrincipal($currentIdentity)
                $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
            }
        }
    }
)

[array]$passedTests = foreach ($test in $tests) {
    $result = & $test.Command
    if (-not $result) {
        Write-Error -Message "The test [$($_.Name)] failed."
    } else {
        1
    }
}

if ($passedTests.Count -eq $tests.Count) {
    Write-Host "All tests have passed. You're good to go!" -ForegroundColor Green
}