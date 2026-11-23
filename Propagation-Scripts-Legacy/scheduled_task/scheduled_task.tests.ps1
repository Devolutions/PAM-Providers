Describe 'Scheduled task propagation script' {

    $mandatoryParameters = @{
        'Endpoint'         = 'windowsserverhere'
        'EndpointUserName' = 'userhere'
        'EndpointPassword' = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
        'AccountUserName'  = 'taskuserhere'
        'NewPassword'      = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
    }
    $parameterSets = @(
        @{
            label         = 'all scheduled tasks running under the user account'
            parameter_set = $mandatoryParameters
        },
        @{
            label         = 'one specific scheduled task by name'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskName = 'task1'
                })
        },
        @{
            label         = 'multiple specific scheduled tasks by name'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskName = 'task1,task2'
                })
        },
        @{
            label         = 'one task path'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskPath = '\path\to\task1\'
                })
        },
        @{
            label         = 'multiple task paths'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskPath = '\path\to\task1\,\path\to\task2\'
                })
        },
        @{
            label         = 'one specific scheduled task by name and path'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskName = 'task1'
                    ScheduledTaskPath = '\path\to\task1\'
                })
        },
        @{
            label         = 'multiple specific scheduled tasks by name and path'
            parameter_set = ($mandatoryParameters + @{
                    ScheduledTaskName = 'task1,task2'
                    ScheduledTaskPath = '\path\to\task1\,\path\to\task2\'
                })
        }
    )

    It 'has a README doc' {
        "$PSScriptRoot\README.md" | Should -Exist
    }

    It 'has a prerequisites test script' {
        "$PSScriptRoot\prerequisites.tests.ps1" | Should -Exist
    }

    it 'has a DVLS template created' {
        "$PSScriptRoot\template.json" | Should -Exist
    }

    Context 'when no scheduled tasks running the the specified username exist' {

        BeforeAll {
            Mock 'Write-Output'
            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-ScheduledTask' = {}
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }
        }

        It 'throws the expected error message : <_.label>' -ForEach $parameterSets {

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*No scheduled tasks found on * running as * could be found*'

        }

    }

    Context 'when at least one specific scheduled task could not be found' {

        $ctxParameterSets = $parameterSets.where({ $_.parameter_set.ContainsKey('ScheduledTaskName') })

        BeforeAll {
            Mock 'Write-Output'
            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Set-ScheduledTask'  = {}
                    'Get-ScheduledTask' = {
                        @([pscustomobject]@{
                            TaskName      = 'nomatchingname'
                            Principal = @{
                                'UserId' = 'taskuserhere'
                            }
                        }
                        [pscustomobject]@{
                            Name      = 'nomatchingname'
                            StartName = 'somerandomuserhere'
                        })
                    }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }
        }

        It 'throws the expected error message : <_.label>' -ForEach $ctxParameterSets {
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*The following scheduled tasks could not be found on host*'

        }

    }

    Context 'when applicable scheduled tasks are found and running' {

        BeforeAll {
            Mock 'Write-Output'
        }
        
        It 'returns $true if all scheduled tasks are reset successfully : <_.label>' -ForEach $parameterSets {

            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-ScheduledTask'  = {
                        @([pscustomobject]@{
                                TaskName      = 'task1'
                                Principal = [pscustomobject]@{
                                    'UserId' = 'taskuserhere'
                                }
                            }
                            [pscustomobject]@{
                                TaskName      = 'task2'
                                Principal = [pscustomobject]@{
                                    'UserId' = 'taskuserhere'
                                }
                            })
                    }
                    'Set-ScheduledTask'  = {}
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }

            & "$PSScriptRoot\script.ps1" @parameter_set | Should -BeTrue
        }


        It 'throws the expected error when at least one password reset fails with a wrong password : <_.label>' -ForEach $parameterSets {

            Mock Invoke-Command {
                $functionsToDefine = @{
                    'Get-ScheduledTask'  = {
                        @([pscustomobject]@{
                                TaskName      = 'task1'
                                Principal = @{
                                    'UserId' = 'taskuserhere'
                                }
                            }
                            [pscustomobject]@{
                                TaskName      = 'task2'
                                Principal = @{
                                    'UserId' = 'taskuserhere'
                                }
                            })
                    }
                    'Set-ScheduledTask' = {
                        throw 'The user name or password is incorrect'
                    }
                }
    
                # Define mock variables if necessary
                $variablesToDefine = New-Object System.Collections.Generic.List[System.Management.Automation.PSVariable]
    
                # Invoke the script block with mock context and arguments
                $ScriptBlock.InvokeWithContext($functionsToDefine, $variablesToDefine, $ArgumentList)
            }

            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*NewPassword for `[taskuserhere`] user account does not match provider for scheduled task * running on * host*'
        }
    }

    context 'when an invalid string is passed to the ScheduledTaskPath parameter' {

        [array]$ctxParameterSets = $mandatoryParameters + @{ ScheduledTaskPath = 'somethinginvalid'}

        it 'does not allow invalid scheduled task paths' -ForEach $ctxParameterSets {
            { & "$PSScriptRoot\script.ps1" @_ } | Should -Throw "*Cannot validate argument on parameter 'ScheduledTaskPath'*"
        }

    }
}