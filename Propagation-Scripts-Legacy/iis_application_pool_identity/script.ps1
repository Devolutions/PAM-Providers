[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EndpointUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$EndpointPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationPoolIdentityUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$ApplicationPoolName
)

# Output the script parameters and the current user running the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]"

#region Functions
# Function to create a new PSCredential object
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create a new PSCredential object using the provided EndpointUserName and EndpointPassword
$credential = newCredential $EndpointUserName $EndpointPassword

# Define a script block to be executed remotely on the IIS server
$scriptBlock = {
    # Function to decrypt a secure string password
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

    $ErrorActionPreference = 'Stop'

    $username = $args[0]
    $pw = $args[1]
    if ($args.Count -eq 3) { $requestedAppPoolName = $args[2] }
    
    # Check if the WebAdministration module is available, throw an error if not
    if (-not (Get-Module -Name 'WebAdministration' -List)) {
        throw "The required WebAdministration module is not available on host [$(hostname)]."
    }
    
    # Import the WebAdministration module
    Import-Module WebAdministration
    
    # Get all application pools on the IIS server
    $allAppPools = Get-ChildItem IIS:\AppPools
    
    # If ApplicationPoolName is provided, filter the application pools based on the provided names
    if ($requestedAppPoolName) {
        ## To process multiple app pools at once. This approach must be done because DVLS will not allow you to pass an array
        ## of strings via a parameter.
        $appPoolNames = $requestedAppPoolName -split ','
        $allAppPools.where({ $_.Name -in $appPoolNames })
    }
    
    # If no application pools are found, throw an error
    if (!$allAppPools) {
        throw "No application pools found on the host [$(hostname)]."
    }
    
    # Filter application pools running under the provided ApplicationPoolIdentityUserName
    # This will only find all of the application pools that have an idenity running as the requested username
    if (-not ($appPoolsRunningUnderUserName = $allAppPools.where({ $_.processModel.userName -eq $username }))) {
        throw "No application pools found on [$(hostname)] running under the provided UserName of [$($username)]."
    }
    
    # Initialize an array to store the results of each application pool processing
    $results = @()
    
    # Process each application pool
    $appPoolsRunningUnderUserName | ForEach-Object {
        try {
            ## Set the new credentials on the application pool
            Set-ItemProperty -Path "IIS:\AppPools\$($_.name)" -Name 'processModel' -Value @{UserName = $username; password = (decryptPassword($pw)) }
            Write-Output "Successfully reset application pool [$($_.name)]'s identity username of [$($username)]."
            $results += $true
        } catch {
            # If an error occurs, add false to the results array and output the error message
            $results += $false
            Write-Output -InputObject "ERROR: $_"
        }
    }
    
    # Return true if all application pool processing succeeded, false otherwise
    $results -notcontains $false
}

# Invoke the script block remotely on the IIS server using the provided credentials
$invParams = @{
    ComputerName = $Endpoint
    ScriptBlock = $scriptBlock
    Credential = $credential
}
$invArgsList = $ApplicationPoolIdentityUserName,$NewPassword
if ($PSBoundParameters.ContainsKey('ApplicationPoolName')) {
    $invArgsList += $ApplicationPoolName
}
$invParams.ArgumentList = $invArgsList
Invoke-Command @invParams