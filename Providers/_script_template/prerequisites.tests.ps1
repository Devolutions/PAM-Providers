#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

<#
Usage (Pester v5+):

$parameters = @{
    
}

$container = New-PesterContainer -Path '<path>/<to>/sql_server_provider.prerequisites.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderEndpoint
)

describe 'prerequisites' {

    
}