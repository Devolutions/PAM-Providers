#requires ## modules with versions here if any

## These are "Property Mappings" in the DVLS UI
[CmdletBinding()]
Param (
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
    [string]$AccountUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword ## required by DVLS

    ## any other provider-specific parameters here
)

## This is useful to see what parameters DVLS passed to the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]..."


#region Functions
# Handy function to create a new PSCredential object if needed
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}

## Handy function to decrypt a securestring
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
#endregion

## If the endpoint must be connected via WinRM, you can use this example.
$scriptBlock = {
    ## include the decryptPassword function in the remote scriptblock so it's made available.
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

    ## Force all errors to be terminating errors so we can handle them with try/catch
    $ErrorActionPreference = 'Stop'

    #region Prerequisite checks
    ## Include checks here like checking if a module is availabele on the remote computer, necessary files exist, etc.
    #region description

    #region Code to find and reset the password on the object

    #endregion

    <#
        Tips:

        - Use Write-Output if you want messages to appear in the UI
        - Always ensure the script returns a boolean $true value if the password reset was successful
        - Always return an error with throw or Write-Error if the password reset attempt failed
    
    #>

}

# Invoke the script block remotely using the provided credentials
$invParams = @{
    ComputerName = $Endpoint
    ScriptBlock = $scriptBlock
    Credential = $credential ## If using this, use the newCredential function to create it.
}
Invoke-Command @invParams