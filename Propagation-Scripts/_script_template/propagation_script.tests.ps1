#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

<#
Usage (Pester v5+):

$parameters = @{
    Endpoint            = ''
    EndpointUserName    = ''
    EndpointPassword    = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
    AccountNewPassword  = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
}

$container = New-PesterContainer -Path '<path>/<to>/propagation_script.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>
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
    [securestring]$AccountNewPassword
)


Describe '<service> propagation script' {

    $mandatoryParameters = @{
        'EndpointCredential' = $EndpointUserName
        'EndpointHostName' = $Endpoint
        'NewPassword'      = $AccountNewPassword
        'EndpointPassword' = $EndpointPassword
        ## other mandatory parameters (if any)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        ## add hashtables of other parameter sets here ensuring you cover all possible sets
    )

    it 'has a README doc' {

    }

    it 'has a prerequisites test script' {
        
    }
    
    Context 'when...' {
    
        BeforeAll {
            Mock Invoke-Command {
                ## If using WinRM to connect to the endpoint with Invoke-Command, you must use the InvokeWithContext()
                ## method to "mock" cmdlets within the scriptblock passed to Invoke-Command
                $ScriptBlock.InvokeWithContext(@{
                        'Get-Module' = { }
                    }, @())
            }
        }
    
        It 'throws the expected error message : <_.label>' -ForEach $parameterSets {
    
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*.....*'
    
        }
    
    }
}