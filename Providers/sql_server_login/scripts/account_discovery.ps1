<#
.SYNOPSIS
Changes the password for a specified SQL Server login.

.DESCRIPTION
This script updates the password for a given SQL Server login using a secure connection. It supports both SQL Server and Windows authentication methods. Optional parameters allow specifying the SQL Server instance, port, and credentials for SQL Server authentication.

.PARAMETER UserName
The UserName of the SQL Server login whose password needs to be updated.

.PARAMETER NewPassword
The new password for the SQL Server login. This parameter should be a secure string.

.PARAMETER Server
The name or IP address of the SQL Server.

.PARAMETER Instance
The instance of SQL Server to connect to. Defaults to the default instance if not specified.

.PARAMETER ProviderSqlLoginUserName
The UserName for SQL Server authentication. If not specified, Windows authentication is used.

.PARAMETER ProviderSqlLoginPassword
The password for SQL Server authentication. This parameter should be a secure string. Required if ProviderSqlLoginUserName is specified.

.PARAMETER Port
The port number for the SQL Server. Defaults to 1433 if not specified.

.EXAMPLE
PS> .\YourScriptName.ps1 -UserName 'myUser' -NewPassword (ConvertTo-SecureString -AsPlainText "newPassword" -Force) -Server 'localhost'

This example changes the password for 'myUser' on the default SQL Server instance running on 'localhost' using Windows authentication.

.EXAMPLE
PS> .\YourScriptName.ps1 -UserName 'myUser' -NewPassword (ConvertTo-SecureString -AsPlainText "newPassword" -Force) -Server 'myServer' -Instance 'myInstance' -ProviderSqlLoginUserName 'admin' -ProviderSqlLoginPassword (ConvertTo-SecureString -AsPlainText "adminPassword" -Force) -Port 1433

This example changes the password for 'myUser' on a specified instance of SQL Server using SQL Server authentication.

.NOTES
Ensure that the NewPassword and ProviderSqlLoginPassword parameters are passed as secure strings to maintain security best practices.

.LINK
URL to more information, if available

#>
[CmdletBinding()]
[OutputType([System.Management.Automation.PSCustomObject])]
Param (
    [Parameter(Mandatory)]
    [string]$Server,

    [Parameter()]
    [string]$Instance,

    [Parameter()]
    [string]$ProviderSqlLoginUserName,

    [Parameter()]
    $ProviderSqlLoginPassword, ## purposeful no explicit type here to allow DVLS to pass an empty string

    [Parameter()]
    [int]$Port
)

$ErrorActionPreference = 'Stop'

## Define optional default parameter values. We can't use PowerShell parameter defaults because if you set up a property in
## in DVLS and don't provide a value, DVLS will still use the parameter just pass an empty string
if (!$Instance) { $Instance = '.' }
if (!$Port) { $Port = 1433 }
if ($ProviderSqlLoginPassword -and $ProviderSqlLoginPassword.GetType().Name -ne 'securestring') {
    throw "The provider SQL login password must be a secure string."
}
if ($ProviderSqlLoginUserName -xor $ProviderSqlLoginPassword) {
    throw "You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time."
}

function decryptPassword {
    param(
        [securestring]$Password
    )
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function newConnectionString {
    $connectionStringItems = @{
        'Database' = 'master'
        'Server'   = "$Server\$Instance,$Port"
    }
    if ($ProviderSqlLoginUserName -and $ProviderSqlLoginPassword) {
        ## Using SQL login to authenticate
        $connectionStringItems += @{
            'User ID'  = $ProviderSqlLoginUserName
            'Password' = decryptPassword($ProviderSqlLoginPassword)
        }
    } else {
        ## using the currently logged in user via Windows auth to authenticate
        $connectionStringItems += @{
            'Integrated Security' = 'True'
        }
    }
    ($connectionStringItems.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ";"
}

function connectSqlServer {
    param(
        $ConnectionString
    )
    # Create a SQL connection
    $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString

    # # Open the connection
    $connection.Open()
    
    $connection
    
}

function invokeSqlQuery {
    param(
        $Connection,
        [string]$Query
    )
    try {

        # Execute the query
        $command = $Connection.CreateCommand()
        $command.CommandText = $Query

        # Execute the command and process the results
        $reader = $command.ExecuteReader()
        while ($reader.Read()) {
            [PSCustomObject]@{
                'name'          = $reader['name']
                'password_hash' = $reader['password_hash']
            }
        }
    } finally {
        if ($reader) {
            $reader.Close()
        }
    }
}

try {

    $connectionString = newConnectionString

    $connection = connectSqlServer -ConnectionString $connectionString

    $selectProps = @(
        @{'n' = 'id'; e = { $_.name } }
        @{'n' = 'UserName'; e = { $_.name } }
        @{'n' = 'secret'; e = { ($_.password_hash -join '') } }
    )

    invokeSqlQuery -Query "SELECT name, password_hash FROM sys.sql_logins;" -Connection $connection | Select-Object -Property $selectProps
    
} catch {
    $PSCmdlet.ThrowTerminatingError($_)
} finally {
    ## Close the connection and clean up
    if ($connection) { 
        $connection.Close()
    }
}