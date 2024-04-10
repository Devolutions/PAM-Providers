Describe 'AWS Credentials file propagation script' {

    $mandatoryParameters = @{
        'EndpointUserName'  = 'userhere'
        'Endpoint'          = 'iisserverhere'
        'EndpointPassword'  = (ConvertTo-SecureString -String 'eppasswordhere' -AsPlainText -Force)
        'NewPassword'       = (ConvertTo-SecureString -String 'newpasswordhere' -AsPlainText -Force)
        'OldIAMAccessKeyId' = 'OldIAMAccessKeyIdhere'
        'NewIAMAccessKeyId' = 'NewIAMAccessKeyIdhere'
    }

    $parameterSets = @(
        @{
            label         = 'all credential files and all profiles'
            parameter_set = $mandatoryParameters
        }
        @{
            label         = 'single credential file and default profile'
            parameter_set = ($mandatoryParameters + @{
                    CredentialsFilePath = 'C:\Users\someuser\.aws\credentials'
                    ProfileName         = 'default'
                })
        },
        @{
            label         = 'single credential file and other profile'
            parameter_set = ($mandatoryParameters + @{
                    CredentialsFilePath = 'C:\Users\someuser\.aws\credentials'
                    ProfileName         = 'other'
                })
        },
        @{
            label         = 'single credential file and all profile'
            parameter_set = ($mandatoryParameters + @{
                    CredentialsFilePath = 'C:\Users\someuser\.aws\credentials'
                })
        },
        @{
            label         = 'single credential file and multiple profiles'
            parameter_set = ($mandatoryParameters + @{
                    CredentialsFilePath = 'C:\Users\someuser\.aws\credentials'
                    ProfileName         = 'default,other'
                })
        },
        @{
            label         = 'all credential files and default profile'
            parameter_set = ($mandatoryParameters + @{
                    ProfileName = 'default'
                })
        },
        @{
            label         = 'all credential files and other profile'
            parameter_set = ($mandatoryParameters + @{
                    ProfileName = 'other'
                })
        },
        @{
            label         = 'all credential files and other multiple profiles'
            parameter_set = ($mandatoryParameters + @{
                    ProfileName = 'default,other'
                })
        }
    )

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | Should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\aws_credentials_file.tests.ps1" | Should -BeTrue
    }

    It 'passes the expected computer name to Invoke-Command : <_.label>' -ForEach $parameterSets {

        Mock 'Invoke-Command' -ParameterFilter {
            $ComputerName -eq $parameter_set.Endpoint
        } -Verifiable

        $null = & "$PSScriptRoot\script.ps1" @parameter_set | Should -InvokeVerifiable
    }

    It 'passes the expected credential to Invoke-Command : <_.label>' -ForEach $parameterSets {

        function decryptPassword {
            param(
                [securestring]$Password
            )
            try {
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
            } finally {
                ## Clear the decrypted password from memory
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
            }
        }

        Mock 'Invoke-Command' -ParameterFilter {
            $Credential.UserName -eq $parameter_set.EndpointUserName -and
            (decryptPassword($Credential.Password)) -eq (decryptPassword($parameter_set.EndpointPassword))
        } -Verifiable

        $null = & "$PSScriptRoot\script.ps1" @parameter_set | Should -InvokeVerifiable
    }

    Context 'when no profiles are found that contain the required OldIAMAccessKeyId' {

        BeforeAll {
            Mock Write-Output
    
            Mock Invoke-Command {

                $ScriptBlock.InvokeWithContext(@{
                        'Get-ChildItem'    = {
                            [pscustomobject]@{
                                Directory = [pscustomobject]@{
                                    Name = '.aws'
                                }
                                FullName  = 'C:\Users\someuser\.aws\credentials'
                            }
                        }
                        'Get-ItemProperty' = { 'C:\Users' }
                        'Set-Content'      = { Write-Output -InputObject 'changedafile' }
                        'Get-Content'      = {
                            '[default]
                            aws_access_key_id = AKIAIOSFODNN7EXAMPLE
                            aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

                            [other]
                            aws_access_key_id = AKIAI44QH8DHBEXAMPLE
                            aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY'
                        }
                    }, @())
            }
        }
        

        It 'does not attempt to update any file : <_.label>' -ForEach $parameterSets {
            & "$PSScriptRoot\script.ps1" @parameter_set | Should -Not -Be 'changedafile'
        }
    }

    # Context 'when no profiles are found that contain the required OldIAMAccessKeyId' {


    #     BeforeAll {
    #         Mock Write-Output
    
    #         Mock Invoke-Command {
    #             $ScriptBlock.InvokeWithContext(@{
    #                     'Get-ChildItem'    = {
    #                         [pscustomobject]@{
    #                             Directory = [pscustomobject]@{
    #                                 Name = '.aws'
    #                             }
    #                             FullName  = 'C:\Users\someuser\.aws\credentials'
    #                         }
    #                     }
    #                     'Get-ItemProperty' = { 'C:\Users' }
    #                     'Set-Content'      = { Write-Output -InputObject 'changedafile' }
    #                     'Get-Content'      = {
    #                         '[default]
    #                         aws_access_key_id = AKIAIOSFODNN7EXAMPLE
    #                         aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

    #                         [other]
    #                         aws_access_key_id = AKIAI44QH8DHBEXAMPLE
    #                         aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY'
    #                     }
    #                 }, @())
    #         }
    #     }
        

    #     It 'does not attempt to update any file : <_.label>' -ForEach $parameterSets {
    #         & "$PSScriptRoot\script.ps1" @parameter_set | Should -Not -Be 'changedafile'
    #     }
    # }

    # Context 'when the script does not have access to a credentials file' {


    #     BeforeAll {
    # mock Write-Output
    #         Mock Invoke-Command {
    #             $ScriptBlock.InvokeWithContext(@{
    #                     'Import-Module' = {}
    #                     'Get-ChildItem' = {}
    #                 }, @())
    #         }
    #     }
        

    #     It 'returns nothing : <_.label>' -ForEach $parameterSets {
    #         & "$PSScriptRoot\script.ps1" @parameter_set | should -BeNullOrEmpty
    #     }
    # }

    # Context 'when a credentials file is not in the expected format' {


    #     BeforeAll {
    # mock Write-Output
    #         Mock Invoke-Command {
    #             $ScriptBlock.InvokeWithContext(@{
    #                     'Import-Module' = {}
    #                     'Get-ChildItem' = {}
    #                 }, @())
    #         }
    #     }
        

    #     It 'returns nothing : <_.label>' -ForEach $parameterSets {
    #         & "$PSScriptRoot\script.ps1" @parameter_set | should -BeNullOrEmpty
    #     }
    # }

    # Context 'when the script cannot connect to the remote host' {


    #     BeforeAll {
    # mock Write-Output
    #         Mock Invoke-Command {
    #             $ScriptBlock.InvokeWithContext(@{
    #                     'Import-Module' = {}
    #                     'Get-ChildItem' = {}
    #                 }, @())
    #         }
    #     }
        

    #     It 'returns nothing : <_.label>' -ForEach $parameterSets {
    #         & "$PSScriptRoot\script.ps1" @parameter_set | should -BeNullOrEmpty
    #     }
    # }
}