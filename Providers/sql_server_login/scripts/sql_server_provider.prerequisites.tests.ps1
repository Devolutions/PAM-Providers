#requires -Version 7

<#
.SYNOPSIS
This script tests SQL Server connectivity and permissions.
.DESCRIPTION
The script performs various connectivity and permission tests on a SQL Server instance using both SQL login and Windows credentials.
.PARAMETER Endpoint
Specifies the SQL Server endpoint.
.PARAMETER Port
Specifies the port on which the SQL Server is listening.
.PARAMETER SqlLoginCredential
Specifies the SQL login credentials as a PSCredential object. Either this or WindowsAccountCredential must be provided.
.PARAMETER WindowsAccountCredential
Specifies the Windows account credentials as a PSCredential object. Either this or SqlLoginCredential must be provided.
.EXAMPLE
PS> .\sql_server_provider.prerequisites.tests.ps1.ps1 -Endpoint "sql.example.com" -Port 1433 -SqlLoginCredential $cred
This example tests the SQL Server at sql.example.com on port 1433 using a SQL login stored in $cred.
.EXAMPLE
PS> .\sql_server_provider.prerequisites.tests.ps1.ps1 -Endpoint "sql.example.com" -Port 1433 -WindowsAccountCredential $winCred
This example tests the SQL Server at sql.example.com on port 1433 using Windows authentication with credentials stored in $winCred.
.NOTES
This script includes a function to decrypt passwords from secure strings for use in SQL connection strings.
#>

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
