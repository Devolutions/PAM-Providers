#requires ## modules with verisons here

[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$UserIdentifier,

    [Parameter(Mandatory)]
    [securestring]$NewPassword,

    ## must have parameters to provide an endpoint/server/something to connect to
    [Parameter(Mandatory)]
    [string]$Endpoint,

    [Parameter(Mandatory)]
    [string]$EndpointUserName, ## must have a way to pass credentials to the remote endpoint if not running over WinRM

    [Parameter(Mandatory)]
    [securestring]$EndpointPassword  ## must have a way to pass credentials to the remote endpoint if not running over WinRM
)

$ErrorActionPreference = 'Stop'

## This is useful to see what parameters DVLS passed to the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String)"

try {

    ## $result = Dowhatevertochangethepasword
    if ($Result) {
        Return $True
    } else {
        Write-Error "Failed to Update Secret"
    }
    
} catch {

}