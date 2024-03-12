#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

Describe '<service> propagation script' {

    $mandatoryParameters = @{
        Endpoint           = ''
        EndpointUserName   = ''
        EndpointPassword   = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        AccountNewPassword = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        ## other mandatory parameters (if any)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        ## add hashtables of other parameter sets here ensuring you cover all possible sets
    )

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\<password propagation script name>..tests.ps1" | should -BeTrue
    }
    
    It 'has the DVLS JSON export' {
        Test-Path "$PSScriptRoot\template.json" | should -BeTrue
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