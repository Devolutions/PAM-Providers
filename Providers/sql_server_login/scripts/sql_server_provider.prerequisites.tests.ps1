#requires -Version 7

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

function runPwshAs([pscredential]$Credential, [scriptblock]$Code) {

    $psFilePath = (Get-Process -Id $PID).Path

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $psFilePath
    $processInfo.Arguments = "-NoProfile -Command & {$($Code.ToString())} -Endpoint '$Endpoint' -Port $Port"
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.LoadUserProfile = $false
    $processInfo.RedirectStandardError = $true
    $processInfo.CreateNoWindow = $true
    $processInfo.UserName = $cred.GetNetworkCredential().UserName
    $processInfo.Password = $cred.Password

    $credDomain = $cred.GetNetworkCredential().Domain
    if ($credDomain) {
        $processInfo.Domain = $credDomain
    } else {
        $processInfo.Domain = (hostname)
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $process.WaitForExit()
    $process
}

[array]$tests = @(
    @{
        'Name'    = 'the SQL Server connection port is open'
        'Command' = {

            try {
                $result = Test-Connection -TargetName $Endpoint -TcpPort $Port -Quiet
            } catch {
                $errMsg = $_.Exception.Message
            }

            [pscustomobject]@{
                'ErrorMessage' = $errMsg
                'Result'       = $result
            }
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
                $errMsg = $_.Exception.Message
            } finally {
                $connection.Close()
            }

            [pscustomobject]@{
                'ErrorMessage' = $errMsg
                'Result'       = !$errMsg
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
                
                $sqlResult = $command.ExecuteScalar() -eq 1
            } catch {
                $errMsg = $_.Exception.Message
            } finally {
                $connection.Close()
            }

            [pscustomobject]@{
                'ErrorMessage' = $errMsg
                'Result'       = $sqlResult
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

            $process = runPwshAs $WindowsAccountCredential $testCode

            $stdError = $process.StandardError.ReadToEnd()

            [pscustomobject]@{
                'ErrorMessage' = $stdError
                'Result'       = !$stdError
            }
        }
        'ParametersUsed' = @('WindowsAccountCredential')
    }
    @{
        'Name'           = 'the Windows account has permission to update SQL login passwords'
        'Command'        = {
            
            $testCode = {
                param($Endpoint, $Port)
                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = ('Server={0},{1};Database=master;Integrated Security=True;' -f $Endpoint, $Port)
                try {
                    $connection.Open()

                    $command = $connection.CreateCommand()
                    $command.CommandText = "SELECT CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_SRVROLEMEMBER('securityadmin') = 1 OR IS_ROLEMEMBER('db_owner') = 1 THEN 1 ELSE 0 END"
            
                    $command.ExecuteScalar() | Should -Be 1
                    $connection.Close()
                } catch {
                    Write-Output 'inconclusive'
                }
            }

            $process = runPwshAs $WindowsAccountCredential $testCode

            $stdError = $process.StandardError.ReadToEnd()
            $stdOutput = $process.StandardOutput.ReadToEnd()

            [pscustomobject]@{
                'ErrorMessage' = $stdError
                'Result'       = (!$stdOutput -and !$stdError)
            }
        }
        'ParametersUsed' = @('WindowsAccountCredential')
    }
)

[array]$passedTests = foreach ($test in $tests.where({ $paramsUsed = $_.ParametersUsed; !$_.ContainsKey('ParametersUsed') -or $PSBoundParameters.Keys.where({ $_ -in $paramsUsed }) })) {
    $result = & $test.Command
    if (-not $result.Result) {
        Write-Error -Message "The test [$($test.Name)] failed: [$($result.ErrorMessage)]"
    } else {
        1
    }
}

if ($passedTests.Count -eq $tests.Count) {
    Write-Host "All tests have passed. You're good to go!" -ForegroundColor Green
}
