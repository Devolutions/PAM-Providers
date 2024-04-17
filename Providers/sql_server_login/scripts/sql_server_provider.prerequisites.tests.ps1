param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [int]$Port,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$SqlLoginCredential,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$WindowsAccountCredential
)

if (-not $SqlLoginCredential -and -not $WindowsAccountCredential) {
    throw 'Either the SqlLoginCredential and/or the WindowsAccountCredential parameter must be used.'
}

function decryptPassword([securestring]$Password) {
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

[array]$tests = @(
    @{
        'Name'    = 'the SQL Server connection port is open'
        'Command' = {
            Test-Connection -TargetName $Endpoint -TcpPort $Port -Quiet
        }
    },
    @{
        'Name'           = 'the provider SQL login UserName can authenticate to the SQL server'
        'Command'        = {
            try {
                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$Endpoint\.,$Port;Database=master;User ID=$($SqlLoginCredential.UserName);Password=$(decryptPassword($SqlLoginCredential.Password));"
                $connection.Open()
                $true
            } catch {
                $false
            } finally {
                $connection.Close()
            }
            
        }
        'ParametersUsed' = @('SqlLoginCredential')
    },
    @{
        'Name'           = 'the provider SQL login UserName has permission to update SQL login passwords'
        'Command'        = {
            try {
                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$Endpoint\.,$Port;Database=master;User ID=$($SqlLoginCredential.UserName);Password=$(decryptPassword($SqlLoginCredential.Password));"
                $connection.Open()

                $command = $connection.CreateCommand()
                $command.CommandText = "SELECT CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_SRVROLEMEMBER('securityadmin') = 1 OR IS_ROLEMEMBER('db_owner') = 1 THEN 1 ELSE 0 END"
                
                $command.ExecuteScalar() -eq 1
            } catch {
                $false
            } finally {
                $connection.Close()
            }
        }
        'ParametersUsed' = @('SqlLoginCredential')
    },
    @{
        'Name'           = 'the Windows account can authenticate to the SQL server'
        'Command'        = {

            $testCode = {
                param($Endpoint, $Port)
                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = ('Server={0},{1};Database=master;Integrated Security=True;' -f $Endpoint, $Port)
                $connection.Open()
                $connection.Close()
            }

            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "pwsh.exe"
            $processInfo.Arguments = "-NoProfile -Command & {$($testCode.ToString())} -Endpoint '$Endpoint' -Port $Port"
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.LoadUserProfile = $false
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true
            $processInfo.Domain = $cred.GetNetworkCredential().Domain
            $processInfo.UserName = $cred.GetNetworkCredential().UserName
            $processInfo.Password = $cred.Password

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            $process.WaitForExit()
            $errorOutput = $process.StandardError.ReadToEnd()

            !$errorOutput
            
        }
        'ParametersUsed' = @('WindowsAccountCredential')
    },
    @{
        'Name'           = 'the Windows account has permission to update SQL login passwords'
        'Command'        = {
            
            $testCode = {
                param($Endpoint, $Port)
                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = ('Server={0},{1};Database=master;Integrated Security=True;' -f $Endpoint, $Port)
                try {
                    $connection.Open()
                } catch {
                    Write-Output 'inconclusive'
                }
                $command = $connection.CreateCommand()
                $command.CommandText = "SELECT CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_SRVROLEMEMBER('securityadmin') = 1 OR IS_ROLEMEMBER('db_owner') = 1 THEN 1 ELSE 0 END"
            
                $command.ExecuteScalar() | Should -Be 1
                $connection.Close()
            }


            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = "pwsh.exe"
            $processInfo.Arguments = "-NoProfile -Command & {$($testCode.ToString())} -Endpoint '$Endpoint' -Port $Port"
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.LoadUserProfile = $false
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true
            $processInfo.Domain = $cred.GetNetworkCredential().Domain
            $processInfo.UserName = $cred.GetNetworkCredential().UserName
            $processInfo.Password = $cred.Password

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            $process.WaitForExit()
            $errorOutput = $process.StandardError.ReadToEnd()

            !$errorOutput
        }
        'ParametersUsed' = @('WindowsAccountCredential')
    }
)

[array]$passedTests = foreach ($test in $tests.where({ $paramsUsed = $_.ParametersUsed; !$_.ContainsKey('ParametersUsed') -or $PSBoundParameters.Keys.where({ $_ -in $paramsUsed }) })) {
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
