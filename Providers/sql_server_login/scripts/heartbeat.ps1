<#
.SYNOPSIS
Validates if a secret matches the password hash for a SQL Server login.

.DESCRIPTION
This script retrieves the password hash for the specified SQL Server login and compares it against the provided secret to validate if they match.
Returns true if the password hashes match, false otherwise.

.PARAMETER Secret
The secret to compare to the login's password hash.

.PARAMETER UserName 
The SQL Server login to retrieve the password hash for.

.PARAMETER Server
The SQL Server instance to connect to.

.PARAMETER Instance
The name of the SQL Server instance to connect to. Default is the default instance.

.PARAMETER ProviderSqlLoginUserName
The SQL login to use when authenticating to SQL Server. Uses Windows authentication if not specified.

.PARAMETER ProviderSqlLoginPassword 
The password for the provider SQL login. Must be a secure string.  

.PARAMETER Port  
The TCP port to connect to SQL Server on. Default is 1433.

.EXAMPLE 
PS> .\Validate-SqlLoginHash.ps1 -Secret $hashedPassword -UserName sqluser -Server sqlserver

Validates if the $hashedPassword matches the hash for the sqluser login on the sqlserver default instance.

.NOTES
This script executes T-SQL directly so permission requirements are based on the SQL Server permissions of the account used to run it.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$Secret,

    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter(Mandatory)]
    [string]$Server,

    [Parameter()]
    [string]$Instance,

    [Parameter()]
    [string]$ProviderSqlLoginUserName,

    [Parameter()]
    $ProviderSqlLoginPassword,

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
    
    $sqlLoginResult = invokeSqlQuery -Query "SELECT name, password_hash FROM sys.sql_logins WHERE name = '$UserName'" -Connection $connection
    ($sqlLoginResult.password_hash -join '') -eq $Secret
        
} catch {
    $PSCmdlet.ThrowTerminatingError($_)
} finally {
    ## Close the connection and clean up
    if ($connection) { 
        $connection.Close()
    }
}