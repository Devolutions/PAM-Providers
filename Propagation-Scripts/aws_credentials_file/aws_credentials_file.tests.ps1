Describe 'AWS Credentials file propagation script' {

    $mandatoryParameters = @{
        'EndpointUserName'  = 'userhere'
        'Endpoint'          = 'iisserverhere'
        'EndpointPassword'  = (ConvertTo-SecureString -String 'eppasswordhere' -AsPlainText -Force)
        'NewPassword'       = (ConvertTo-SecureString -String 'newpasswordhere' -AsPlainText -Force)
        'OldIAMAccessKeyId' = 'OldIAMAccessKeyIdHere'
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
                
                $sbToTest = {
                    function script:Test-Path { $true }
                    function script:Get-ChildItem {
                        [pscustomobject]@{
                            Directory = [pscustomobject]@{
                                Name = '.aws'
                            }
                            FullName  = 'C:\Users\someuser\.aws\credentials'
                        }
                    }
                    function script:Get-ItemProperty { 'C:\Users' }
                    function script:Set-Content { Add-Content -Path TestDrive:\updated.txt -Value '' }
                    function script:Get-Content {
                        '[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[other]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY'
                    }

                    $ScriptBlock.Invoke($ArgumentList)
                }

                & $sbToTest
            }
        }
        

        It 'does not attempt to update any file : <_.label>' -ForEach $parameterSets {
            $null = & "$PSScriptRoot\script.ps1" @parameter_set
            Test-Path TestDrive:\updated.txt | Should -BeFalse
        }
    }

    Context 'when profiles are found that contain the required OldIAMAccessKeyId' {

        BeforeAll {
            Mock Write-Output
    
            Mock Invoke-Command {
                
                $sbToTest = {
                    function script:Test-Path { $true }
                    function script:Get-ChildItem {
                        [pscustomobject]@{
                            Directory = [pscustomobject]@{
                                Name = '.aws'
                            }
                            FullName  = 'C:\Users\someuser\.aws\credentials'
                        }
                    }
                    function script:Get-ItemProperty { 'C:\Users' }
                    function script:Set-Content { Add-Content -Path TestDrive:\updated.txt -Value '' }
                    function script:Get-Content {
                        '[default]
aws_access_key_id = OldIAMAccessKeyIdHere
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[other]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY'
                    }

                    $ScriptBlock.Invoke($ArgumentList)
                }

                & $sbToTest
            }
        }
        

        It 'attempts to update a credentials file : <_.label>' -ForEach $parameterSets {
            $null = & "$PSScriptRoot\script.ps1" @parameter_set
            Test-Path TestDrive:\updated.txt | Should -BeTrue
        }
    }

    Context 'when the script does not have access to a credentials file' {

        BeforeAll {
            Mock Write-Output
    
            Mock Invoke-Command {
                
                $sbToTest = {
                    function script:Test-Path { $true }
                    function script:Get-ChildItem {
                        throw [System.UnauthorizedAccessException]"Access to the path is denied."
                    }
                    function script:Get-ItemProperty { 'C:\Users' }
                    function script:Set-Content { Add-Content -Path TestDrive:\updated.txt -Value '' }
                    function script:Get-Content {
                        '[default]
aws_access_key_id = OldIAMAccessKeyIdHere
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[other]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY'
                    }

                    $ScriptBlock.Invoke($ArgumentList)
                }

                & $sbToTest
            }
        }

        It 'throws an error : <_.label>' -ForEach $parameterSets {
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*Access to the path*'
        }

    }

    Context 'when the script cannot connect to the remote host' {


        BeforeAll {
            Mock Write-Output
            Mock Invoke-Command {
                throw [System.Management.Automation.Remoting.PSRemotingTransportException]"Cannot connect to remote computer."
            }
        }
        

        It 'returns the expected error : <_.label>' -ForEach $parameterSets {
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*unable to connect to the remote computer*'
        }
    }
}