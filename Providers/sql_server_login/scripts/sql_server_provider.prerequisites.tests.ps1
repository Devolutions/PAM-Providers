#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

<#
Usage (Pester v5+):

$parameters = @{
    ProviderEndpoint = 'xxxxxxx'
    Database = 'xxxx'
    Port = 1433
    Instance = '.'
    ProviderSqlLoginUserName = 'xxxxxxx'
    ProviderSqlLoginPassword = (ConvertTo-SecureString -String 'xxxxx' -AsPlainText -Force)
}

$container = New-PesterContainer -Path '<path>/<to>/sql_server_provider.prerequisites.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderEndpoint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Database,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [int]$Port,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Instance,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [securestring]$ProviderSqlLoginPassword,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderSqlLoginUserName
)

describe 'prerequisites' {

    BeforeAll {
        function decryptPassword([securestring]$Password) {
            try {
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            } finally {
                ## Clear the decrypted password from memory
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }
    }

    It "the SQL Server connection port is open" {

        Test-Connection -TargetName $ProviderEndpoint -TcpPort $Port -Quiet | Should -BeTrue

    }

    Context 'SQL authentication' {

        if ($ProviderSqlLoginUserName -and $ProviderSqlLoginPassword) {

            it 'the provider SQL login UserName can authenticate to the SQL server' {

                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$ProviderEndpoint\.,$Port;Database=master;User ID=$ProviderSqlLoginUserName;Password=$(decryptPassword($ProviderSqlLoginPassword));"
                { $connection.Open() } | Should -Not -Throw
                $connection.Close()
            }
            
            it 'the provider SQL login UserName has permission to update SQL login passwords' {

                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$ProviderEndpoint\.,$Port;Database=$Database;User ID=$ProviderSqlLoginUserName;Password=$(decryptPassword($ProviderSqlLoginPassword));"
                try {
                    $connection.Open()
                } catch {
                    Set-ItResult -Inconclusive
                }

                $command = $connection.CreateCommand()
                $command.CommandText = "SELECT CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_SRVROLEMEMBER('securityadmin') = 1 OR IS_ROLEMEMBER('db_owner') = 1 THEN 1 ELSE 0 END"
            
                $command.ExecuteScalar() | Should -Be 1
                $connection.Close()
            }
        }
    }

    Context 'Windows authentication' {

        if (!$ProviderSqlLoginUserName -and !$ProviderSqlLoginPassword) {

            it 'the logged-in Windows account can authenticate to the SQL server' {

                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$ProviderEndpoint\.,$Port;Database=master;Integrated Security=True;"
                { $connection.Open() } | Should -Not -Throw
                $connection.Close()
            }
            
            it 'the logged-in Windows account has permission to update SQL login passwords' {

                $connection = New-Object System.Data.SqlClient.SqlConnection
                $connection.ConnectionString = "Server=$ProviderEndpoint\.,$Port;Database=master;Integrated Security=True;"
                try {
                    $connection.Open()
                } catch {
                    Set-ItResult -Inconclusive
                }

                $command = $connection.CreateCommand()
                $command.CommandText = "SELECT CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR IS_SRVROLEMEMBER('securityadmin') = 1 OR IS_ROLEMEMBER('db_owner') = 1 THEN 1 ELSE 0 END"
            
                $command.ExecuteScalar() | Should -Be 1
                $connection.Close()
            }
        }
    }
}