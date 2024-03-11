#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

<#
Usage (Pester v5+):

$parameters = @{
    
}

$container = New-PesterContainer -Path '<path>/<to>/prerequisites.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [pscredential]$EndpointCredential
)

describe 'prerequisites' {

    it "the endpoint can be connected to via WinRM with the provided credential" {

        Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock {1} | Should -Be 1

    }

    ## add any other necessary prereqs here

}