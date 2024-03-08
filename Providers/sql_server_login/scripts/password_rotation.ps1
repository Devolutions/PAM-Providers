<#
.SYNOPSIS
Changes the password for a SQL Server login.

.DESCRIPTION
This script changes the password for the specified SQL Server login by executing an ALTER LOGIN statement. 

.PARAMETER UserName
The name of the SQL Server login to change the password for.

.PARAMETER NewPassword
The new password to set for the SQL Server login. Must be a secure string.

.PARAMETER Server
The name of the SQL Server to connect to.

.PARAMETER Instance
The name of the SQL Server instance to connect to. Default is the default instance.

.PARAMETER ProviderSqlLoginUserName
The SQL login to use when authenticating to SQL Server. Uses Windows authentication if not specified.

.PARAMETER ProviderSqlLoginPassword  
The password for the provider SQL login. Must be a secure string.

.PARAMETER Port
The TCP port to connect to SQL Server on. Default is 1433.

.EXAMPLE 
PS> .\Set-SqlLoginPassword.ps1 -UserName sqluser -NewPassword $password -Server sqlserver

Changes the password for the sqluser login on the default instance of the sqlserver SQL Server using Windows authentication.

.NOTES
This script executes T-SQL directly so permission requirements are based on the SQL Server permissions of the account used to run it rather than the PowerShell process account.
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter(Mandatory)]
    $NewPassword,

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
if ($NewPassword -and $NewPassword.GetType().Name -ne 'securestring') {
    throw "The new password must be a secure string."
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

    # Execute the query
    $command = $Connection.CreateCommand()
    $command.CommandText = $Query

    # Execute the command and process the results
    $command.ExecuteReader()
}

try {
    
    $connectionString = newConnectionString

    $connection = connectSqlServer -ConnectionString $connectionString
    
    invokeSqlQuery -Query "ALTER LOGIN [$UserName] WITH PASSWORD = '$(decryptPassword($NewPassword))';" -Connection $connection
    $true

} catch {
    $PSCmdlet.ThrowTerminatingError($_)
} finally {
    ## Close the connection and clean up
    if ($connection) { 
        $connection.Close()
    }
}