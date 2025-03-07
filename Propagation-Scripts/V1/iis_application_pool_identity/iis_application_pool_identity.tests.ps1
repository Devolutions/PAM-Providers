Describe 'IIS Application Pool Identity propagation script' {

    $mandatoryParameters = @{
        'EndpointUserName'                = 'userhere'
        'Endpoint'                        = 'iisserverhere'
        'NewPassword'                     = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        'EndpointPassword'                = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        'ApplicationPoolIdentityUserName' = 'apppooliduserhere'
    }

    $parameterSets = @(
        @{
            label         = 'all app pools'
            parameter_set = $mandatoryParameters
        }
        @{
            label         = 'single app pool'
            parameter_set = ($mandatoryParameters + @{
                    ApplicationPoolName = 'apppool1'
                })
        },
        @{
            label         = 'comma-separated app pools'
            parameter_set = ($mandatoryParameters + @{
                    ApplicationPoolName = 'apppool1,apppool2'
                })
        }
    )

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\iis_application_pool_identity.tests.ps1" | should -BeTrue
    }

    Context 'when the WebAdministration module is not available on the host' {

        BeforeAll {
            Mock Invoke-Command {
                $ScriptBlock.InvokeWithContext(@{
                        'Get-Module' = { }
                    }, @())
            }
        }

        It 'throws the expected error message : <_.label>' -ForEach $parameterSets {

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*The required WebAdministration module is not available on host*'

        }

    }

    Context 'when there are no application pools found on the host' {


        BeforeAll {

            Mock Invoke-Command {
                $ScriptBlock.InvokeWithContext(@{
                        'Get-Module'    = { 'something' }
                        'Import-Module' = {}
                        'Get-ChildItem' = {}
                    }, @())
            }
        }
        

        It 'throws the expected error : <_.label>' -ForEach $parameterSets {

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*No application pools found*'
        }
    }

    # Context 'when there are no application pools found running under the specified username' {

    #     BeforeAll {

    #         Mock Invoke-Command {
    #             $ScriptBlock.InvokeWithContext(@{
    #                     'Get-Module'    = { 'something' }
    #                     'Import-Module' = {}
    #                     'Get-ChildItem' = { [pscustomobject]@{
    #                             'processModel' = [pscustomobject]@{
    #                                 'userName' = 'someotheruser'
    #                             }
    #                         } }
    #                 }, @())
    #         }
    #     }

    #     It 'throws the expected error : <_.label>' -ForEach $parameterSets {
    #         { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*running under the provided UserName of*'
    #     }

    # }

    Context 'when multiple app pools exist, are started and are running under the specified username' {

        BeforeAll {
            Mock Invoke-Command {
                # Define mock functions
                $functionsToDefine = @{
                    'Get-Module'       = { 'soething' }
                    'Import-Module'    = { }
                    'Get-ChildItem'    = {
                        [pscustomobject]@{
                                'state'        = 'Started'
                                'name'         = 'apppool1'
                                'processModel' = [pscustomobject]@{
                                    'userName' = $ArgumentList[0]
                                } 
                            },
                            [pscustomobject]@{
                                'state'        = 'Started'
                                'name'         = 'apppool2'
                                'processModel' = [pscustomobject]@{
                                    'userName' = $ArgumentList[0]
                                }
                            }
                    }
                    'Set-ItemProperty' = { }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }
        }

        It 'returns $true for each app pool identity reset : <_.label>' -ForEach $parameterSets {

            & "$PSScriptRoot\script.ps1" @parameter_set| Should -BeTrue

        }
    }
}