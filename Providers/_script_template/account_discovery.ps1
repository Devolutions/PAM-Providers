#requires ## modules with versions here

[CmdletBinding()]
param (
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

    <#
        Your script should always return an object with a unique identifier with a property name of 'id', a name
        with the property name of 'UserName' and (optionally) a 'secret' property with the password hash (or possibly
        the plaintext password for the user account.

        These properties must match the properties in the heartbeat script.

        Example to transform the property names
        $selectProps = @(
            @{'n'='id';e={$_.name}}
            @{'n'='UserName';e={$_.name}} ## not sure if this is needed
            @{'n'='secret';e={($_.password_hash -join '')}} ## this must be the same type as the heartbeat script's parameter of the same name should be
        )
        Get-SomeCommandToGetUserNamesandPasswords | Select-Object -Property $selectprops

        This can return one or more accounts.
    #>
    
} catch {

} finally {

}