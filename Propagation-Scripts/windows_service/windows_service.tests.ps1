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
                    RestartService = 'yes'
                })
        }
        @{
            label         = 'multiple specific services to restart'
            parameter_set = ($mandatoryParameters + @{
                    ServiceName    = 'service1,service2'
                    RestartService = 'yes'
                })
        }
        @{
            label         = 'all services to restart'
            parameter_set = ($mandatoryParameters + @{
                    RestartService = 'yes'
                })
        }
    )

    It 'has a README doc' {
        "$PSScriptRoot\README.md" | Should -Exist
    }

    It 'has a prerequisites test script' {
        "$PSScriptRoot\prerequisites.tests.ps1" | Should -Exist
    }

    It 'has a DVLS template created' {
        "$PSScriptRoot\template.json" | Should -Exist
    }

    Context 'when no services running the the specified username exist' {

        $ctxParameterSets = $parameterSets.where({ !$_.parameter_set.ContainsKey('ServiceName') })

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

        It 'throws the expected error message : <_.label>' -ForEach $ctxParameterSets {

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*No services found on * running as * could be found*'

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

    Context 'when applicable services are found and not running' {

        BeforeAll {
            Mock 'Write-Output'
            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-CimInstance' = {
                        [pscustomobject]@{
                            Name      = 'service1'
                            StartName = 'serviceuserhere'
                            State     = 'Stopped'
                        }
                        [pscustomobject]@{
                            Name      = 'service2'
                            StartName = 'serviceuserhere'
                            State     = 'Stopped'
                        }
                    }
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
        }


        It 'returns true : <_.label>' -ForEach $parameterSets {

            & "$PSScriptRoot\script.ps1" @parameter_set | Should -BeTrue
        }
    }
}