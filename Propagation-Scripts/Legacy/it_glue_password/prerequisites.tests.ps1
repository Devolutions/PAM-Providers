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
    [string]$EndpointUri,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [pscredential]$EndpointApiKey
)

describe 'prerequisites' {

    it 'the API key has the appropriate permisions to update user passwords' {
        Set-ItResult -Inconclusive -Because 'the test has not been created'
    }

    

}