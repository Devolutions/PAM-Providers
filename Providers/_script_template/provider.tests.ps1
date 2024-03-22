#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

Describe 'provider' {

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | Should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\<provider_name>.tests.ps1" | Should -BeTrue
    }

    it 'does not save anything to disk' {
        ## anything needed on disk like PowerShell modules and files need to be set up ahead of time
        Set-ItResult -Inconclusive
    }
}

Describe 'account discovery' {

    $mandatoryParameters = @{
        Endpoint         = ''
        EndpointUserName = ''
        EndpointPassword = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        ## other mandatory parameters (if any)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        ## add hashtables of other parameter sets here ensuring you cover all possible sets
    )


    
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

        it 'does not save anything to disk' {
            ## anything needed on disk like PowerShell modules and files need to be set up ahead of time
            Set-ItResult -Inconclusive
        }
    
    }
}

Describe 'heartbeat' {

    $mandatoryParameters = @{
        Endpoint         = ''
        EndpointUserName = ''
        EndpointPassword = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        Secret           = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        ## other mandatory parameters (if any)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        ## add hashtables of other parameter sets here ensuring you cover all possible sets
    )
    
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

        it 'does not save anything to disk' {
            ## anything needed on disk like PowerShell modules and files need to be set up ahead of time
            Set-ItResult -Inconclusive
        }
    
    }
}

Describe 'password rotation' {

    $mandatoryParameters = @{
        Endpoint         = ''
        EndpointUserName = ''
        EndpointPassword = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        NewPassword      = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        UserIdentifier   = ''
        ## other mandatory parameters (if any)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        ## add hashtables of other parameter sets here ensuring you cover all possible sets
    )
    
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

        it 'does not save anything to disk' {
            ## anything needed on disk like PowerShell modules and files need to be set up ahead of time
            Set-ItResult -Inconclusive
        }
    
    }
}