[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Username,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$Password,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$Hostname,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [String]$LoginUsername,
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$LoginPassword
)

$ScriptBlock = {
    param (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]$Username,
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [SecureString]$Password
    )
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement
    #$obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$Hostname)
    $ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine, $env:computername
    $opt = [System.DirectoryServices.AccountManagement.ContextOptions]::SimpleBind
    $obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $ct
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    $result = $obj.ValidateCredentials($Username, $UnsecurePassword)
    if ($result -ne $true) {
        Write-Error \"The username or password does not match the credential on the machine\";
    }
    
    Write-Output $result
}


try {
    $Credential = New-Object System.Management.Automation.PSCredential @($LoginUsername, $LoginPassword)
    $PSSession = New-PSSession $HostName -Credential $Credential
    $Results = Invoke-Command -Session $PSSession -ArgumentList @($UserName, $Password) -ScriptBlock $ScriptBlock -ErrorAction 'Stop'
    Write-Output $Results
} catch {
    Write-Error $error[0].Exception.ToString()
}