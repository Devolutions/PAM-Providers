#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

<#
Usage (Pester v5+):

$cred=Get-Credential

$parameters = @{
    Endpoint = 'xxxx'
    Credential = $cred
}

$container = New-PesterContainer -Path '<path>/<to>/<provider>.prerequisites.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [pscredential]$EndpointCredential
)

Describe 'prerequisites' {

    It "the endpoint can be connected to via WinRM with the provided credential" {

        Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock { 1 } | Should -Be 1

    }

    It 'has the WebAdministration PowerShell module available' {

        Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock { Get-Module WebAdministration -List } | Should -Not -BeNullOrEmpty

    }

    It 'the IIS role is installed' {

        Invoke-Command -ComputerName $Endpoint -Credential $EndpointCredential -ScriptBlock { (Get-WindowsFeature Web-Server).InstallState } | Should -Be 1
    
    }

}