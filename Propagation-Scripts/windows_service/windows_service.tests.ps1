Describe 'Windows Service propagation script' {

    $mandatoryParameters = @{
        'Endpoint'         = 'windowsserverhere'
        'EndpointUserName' = 'userhere'
        'EndpointPassword' = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        'AccountUserName'  = 'serviceuserhere'
        'NewPassword'      = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
    }

    $parameterSets = @(
        @{
            label         = 'all services running under the user account'
            parameter_set = $mandatoryParameters
        }
        @{
            label         = 'one specific service'
            parameter_set = ($mandatoryParameters + @{
                    ServiceName = 'service1'
                })
        },
        @{
            label         = 'multiple specific services'
            parameter_set = ($mandatoryParameters + @{
                    ServiceName = 'service1,service2'
                })
        }
        @{
            label         = 'one specific service to restart'
            parameter_set = ($mandatoryParameters + @{
                    ServiceName    = 'service1'
                    RestartService = $true
                })
        }
        @{
            label         = 'multiple specific services to restart'
            parameter_set = ($mandatoryParameters + @{
                    ServiceName    = 'service1,service2'
                    RestartService = $true
                })
        }
        @{
            label         = 'all services to restart'
            parameter_set = ($mandatoryParameters + @{
                    RestartService = $true
                })
        }
    )

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | Should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\prerequisites.tests.ps1" | Should -BeTrue
    }

    Context 'when no services running the the specified username exist' {

        BeforeAll {
            Mock 'Write-Output'
            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-CimInstance' = {}
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }
        }

        It 'throws the expected error message : <_.label>' -ForEach $parameterSets {

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*No services found on * running as * could be found*'

        }

    }

    Context 'when at least one specific service could not be found' {

        $ctxParameterSets = $parameterSets.where({ $_.parameter_set.ContainsKey('ServiceName') })

        BeforeAll {
            Mock 'Write-Output'
            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-CimInstance' = {
                        [pscustomobject]@{
                            Name      = 'nomatchingservicename'
                            StartName = 'somerandomuserhere'
                        }
                    }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }
        }

        It 'throws the expected error message : <_.label>' -ForEach $ctxParameterSets {
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*The following services could not be found on host*'

        }

    }

    Context 'when applicable services are found and running' {

        BeforeAll {
            Mock 'Write-Output'
        }
        
        It 'returns $true if all service accounts are reset successfully : <_.label>' -ForEach $parameterSets {

            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-CimInstance'  = {
                        @([pscustomobject]@{
                                Name      = 'service1'
                                StartName = 'serviceuserhere'
                                State     = 'Running'
                            }
                            [pscustomobject]@{
                                Name      = 'service2'
                                StartName = 'serviceuserhere'
                                State     = 'Running'
                            })
                    }
                    'Restart-Service'  = {}
                    'Invoke-CimMethod' = {
                        [pscustomobject]@{
                            ReturnValue = 0
                        }
                    }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }

            & "$PSScriptRoot\script.ps1" @parameter_set | Should -BeTrue
        }


        It 'throws the expected error when at least one service account password reset fails : <_.label>' -ForEach $parameterSets {

            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-CimInstance'  = {
                        @([pscustomobject]@{
                                Name      = 'service1'
                                StartName = 'serviceuserhere'
                                State     = 'Running'
                            }
                            [pscustomobject]@{
                                Name      = 'service2'
                                StartName = 'serviceuserhere'
                                State     = 'Running'
                            })
                    }
                    'Restart-Service'  = {}
                    'Invoke-CimMethod' = {
                        [pscustomobject]@{
                            ReturnValue = 1
                        }
                    }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*Password update for service * failed with return value*'

        }
    }

    # context 'when applicable services are found and not running' {

    #     BeforeAll {
    #         mock 'Write-Output'
    #         Mock Invoke-Command {
    #             $functionsToDefine = @{
    #                 'Get-CimInstance'       = {
    #                     [pscustomobject]@{
    #                         Name = 'service1'
    #                         StartName = 'serviceuserhere'
    #                         State = 'Stopped'
    #                     }
    #                     [pscustomobject]@{
    #                         Name = 'service2'
    #                         StartName = 'serviceuserhere'
    #                         State = 'Stopped'
    #                     }
    #                 }
    #             }
    
    #             # Define mock variables if necessary
    #             $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
    #             # Invoke the script block with mock context and arguments
    #             $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
    #         }
    #     }
        

    # }

    # context 'when an applicable service is not running' {

    # }

    # context 'when the update password method fails' {

    # }
}