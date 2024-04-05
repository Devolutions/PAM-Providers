<#
Usage (Pester v5+):

account discovery
-----------------------------
$parameters = @{
    ProviderSqlLoginUserName = 'xxxxxxx'
    ProviderSqlLoginPassword = (ConvertTo-SecureString -String 'xxxxx' -AsPlainText -Force)
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
}

$parameters = @{
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
}

heartbeat
-----------------------------
$parameters = @{
    ProviderSqlLoginUserName = 'xxxxxxx'
    ProviderSqlLoginPassword = (ConvertTo-SecureString -String 'xxxxx' -AsPlainText -Force)
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
    Secret = '<password hash returned from account_discovery.ps1>'
    UserName = '<sql login UserName>'
}

$parameters = @{
    ProviderEndpoint = 'xxxxxxx'
    Secret = '<password hash returned from account_discovery.ps1>'
    UserName = '<sql login UserName>'
}

password rotation
-----------------------------
$parameters = @{
    ProviderSqlLoginUserName = 'xxxxxxx'
    ProviderSqlLoginPassword = (ConvertTo-SecureString -String 'xxxxx' -AsPlainText -Force)
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
    UserName = '<sql login UserName>'
    NewPassword = '<a secure string>'
}

$parameters = @{
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
    Secret = '<password hash returned from account_discovery.ps1>'
    UserName = '<sql login UserName>'
    NewPassword = '<a secure string>'
}



all tests at once
------------------------
$parameters = @{
    ProviderSqlLoginUserName = 'xxxxxxx'
    ProviderSqlLoginPassword = (ConvertTo-SecureString -String 'xxxxx' -AsPlainText -Force)
    ProviderEndpoint = 'xxxxxxx'
    UserName = '<sql login UserName>'
    Secret = ''
    Port = 1433
    Instance = '.'
    NewPassword = '<a secure string>'
}

$parameters = @{
    ProviderEndpoint = 'xxxxxxx'
    Port = 1433
    Instance = '.'
    Secret = '<password hash returned from account_discovery.ps1>'
    UserName = '<sql login UserName>'
    Secret = ''
    NewPassword = '<a secure string>'
}

$container = New-PesterContainer -Path '<path>/<to>/account_discovery|heartbeat|password_rotation.tests.ps1' -Data $parameters
Invoke-Pester -Container $container -Output Detailed

#>

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderEndpoint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Instance,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [int]$Port,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [securestring]$ProviderSqlLoginPassword,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ProviderSqlLoginUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Secret,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword
)

Describe 'documentation' {
    It 'the provider has a README file' {
        Test-Path -Path (Join-Path -Path ($PSScriptRoot | Split-Path -Parent) -ChildPath 'README.md') | Should -BeTrue
    }
}

Describe 'account discovery' {

    Context 'SQL authentication' {

        if ($ProviderSqlLoginUserName -and $ProviderSqlLoginPassword) {
            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                        }
                        expected_output = @(
                            [pscustomobject]@{
                                id       = $UserName
                                UserName = $UserName
                                secret   = $Secret
                            }
                        )
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected users for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\account_discovery.ps1" @parameter_set

                $result[0].id | Should -Be $expected_output[0].id
                $result[0].UserName | Should -Be $expected_output[0].UserName
                $result[0].secret | Should -Be $expected_output[0].secret

                $result[1].id | Should -Be $expected_output[1].id
                $result[1].UserName | Should -Be $expected_output[1].UserName
                $result[1].secret | Should -Be $expected_output[1].secret
            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\account_discovery.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }

    Context 'Windows authentication' {

        if (!$ProviderSqlLoginUserName -and !$ProviderSqlLoginPassword) {
            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server   = $ProviderEndpoint
                            Port     = $Port
                            Instance = $Instance
                        }
                        expected_output = @(
                            [pscustomobject]@{
                                id       = $UserName
                                UserName = $UserName
                                secret   = $Secret
                            }
                        )
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server = 'somebogusserver'
                            Port     = $Port
                            Instance = $Instance
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected users for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\account_discovery.ps1" @parameter_set

                $result[0].id | Should -Be $expected_output[0].id
                $result[0].UserName | Should -Be $expected_output[0].UserName
                $result[0].secret | Should -Be $expected_output[0].secret

            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\account_discovery.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }
}

Describe 'heartbeat' {

    Context 'SQL authentication' {

        if ($ProviderSqlLoginUserName -and $ProviderSqlLoginPassword) {

            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            Secret                   = $Secret
                        }
                        expected_output = $true
                    },
                    @{
                        parameter_set   = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            Secret                   = '<something different than what the password hash currently is>'
                        }
                        expected_output = $false
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            UserName                 = $UserName
                            Secret                   = $Secret
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            Secret                   = $Secret
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = 'somebogusserver'
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            Secret                   = $Secret
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected output for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\heartbeat.ps1" @parameter_set

                $result | Should -Be $expected_output
            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\heartbeat.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }

    Context 'Windows authentication' {

        if (!$ProviderSqlLoginUserName -and !$ProviderSqlLoginPassword) {
            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server   = $ProviderEndpoint
                            Port     = $Port
                            Instance = $Instance
                            UserName = $UserName
                            Secret   = $Secret
                        }
                        expected_output = $true
                    },
                    @{
                        parameter_set   = @{
                            Server   = $ProviderEndpoint
                            Port     = $Port
                            Instance = $Instance
                            UserName = $UserName
                            Secret   = '<something different than what the password hash currently is>'
                        }
                        expected_output = $false
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server   = 'somebogusserver'
                            Port     = $Port
                            Instance = $Instance
                            UserName = $UserName
                            Secret   = $Secret
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected output for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\heartbeat.ps1" @parameter_set

                $result | Should -Be $expected_output
            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\heartbeat.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }
}

Describe 'password rotation' {

    ## Don't actually change the password
    Mock 'invokeSqlQuery'

    Context 'SQL authentication' {

        if ($ProviderSqlLoginUserName -and $ProviderSqlLoginPassword) {

            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            NewPassword              = $NewPassword
                        }
                        expected_output = $true
                    },
                    @{
                        parameter_set   = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            NewPassword              = $NewPassword
                        }
                        expected_output = $false
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            UserName                 = $UserName
                            NewPassword              = $NewPassword
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = $ProviderEndpoint
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            NewPassword              = $NewPassword
                        }
                        expected_error_message = 'You must use the ProviderSqlLoginUserName and ProviderSqlLoginPassword parameters at the same time.'
                    }
                    @{
                        parameter_set          = @{
                            Server                   = 'somebogusserver'
                            Port                     = $Port
                            Instance                 = $Instance
                            ProviderSqlLoginUserName = $ProviderSqlLoginUserName
                            ProviderSqlLoginPassword = $ProviderSqlLoginPassword
                            UserName                 = $UserName
                            NewPassword              = $NewPassword
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected output for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\password_rotation.ps1" @parameter_set

                $result | Should -Be $expected_output
            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\password_rotation.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }

    Context 'Windows authentication' {

        if (!$ProviderSqlLoginUserName -and !$ProviderSqlLoginPassword) {
            $tests = @{
                output         = @(
                    @{
                        parameter_set   = @{
                            Server      = $ProviderEndpoint
                            Port        = $Port
                            Instance    = $Instance
                            UserName    = $UserName
                            NewPassword = $NewPassword
                        }
                        expected_output = $true
                    }
                )
                error_handling = @(
                    @{
                        parameter_set          = @{
                            Server      = 'somebogusserver'
                            Port        = $Port
                            Instance    = $Instance
                            UserName    = $UserName
                            NewPassword = $NewPassword
                        }
                        expected_error_message = '*The server was not found or was not accessible*'
                    }
                )
            }

            It "returns the expected output for params: <parameter_set.Keys>" -ForEach $tests.output {

                $result = & "$PSScriptRoot\password_rotation.ps1" @parameter_set

                $result | Should -Be $expected_output
            }

            It 'throws an expected error for params: <parameter_set.Keys>' -ForEach $tests.error_handling {
            
                { & "$PSScriptRoot\password_rotation.ps1" @parameter_set } | Should -Throw $expected_error_message

            }
        }
    }
}