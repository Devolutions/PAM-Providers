#requires -Modules @{ModuleName='Pester';ModuleVersion='5.0.0'}

Describe 'IT Glue propagation script' {

    $mandatoryParameters = @{
        EndpointApiKey = (ConvertTo-SecureString -String 'apikeyhere' -AsPlainText -Force)
        PasswordName   = 'namehere'
        NewPassword    = (ConvertTo-SecureString -String 'passwordhere' -AsPlainText -Force)
    }
    
    $parameterSets = @(
        @{
            label         = 'all mandatory parameters'
            parameter_set = $mandatoryParameters
        }
        @{
            label         = 'specific EndpointUri'
            parameter_set = $mandatoryParameters + @{
                'EndpointUri' = 'https://endpointhere'
            }
        }
    )

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | Should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\prerequisites.tests.ps1" | Should -BeTrue
    }

    It 'has the DVLS exported template' {
        Test-Path "$PSScriptRoot\template.json" | Should -BeTrue
    }

    Context 'when the requested password exists' {

        BeforeAll {

            mock 'Write-Output'

            Mock 'Invoke-RestMethod' -ParameterFilter {
                $Uri -eq "$EndpointUri/passwords/12345?show_password=true"
            } -MockWith {
                $script:respStatus = 200
            }

            Mock 'Invoke-RestMethod' -ParameterFilter {
                $Uri -eq "$EndpointUri/passwords?filter[name]=namehere"
            } -MockWith {

                $script:respStatus = 200

                [pscustomobject]@{
                    'data' = [pscustomobject]@{
                        'id' = 12345
                    }
                }
            }
        }

        it 'passes the expected URI to the API to update the password : <_.label>' -ForEach $parameterSets {

            Mock 'Invoke-RestMethod' -ParameterFilter {
                $Uri -eq "$EndpointUri/passwords/12345?show_password=true"
            } -Verifiable -MockWith {
                $script:respStatus = 200
            }

            & "$PSScriptRoot\script.ps1" @parameter_set | should -InvokeVerifiable
        }

        it 'passes the expected URI to the API to find the password : <_.label>' -ForEach $parameterSets {

            Mock 'Invoke-RestMethod' -ParameterFilter {
                $Uri -eq "$EndpointUri/passwords?filter[name]=namehere"
            } -Verifiable -MockWith {

                $script:respStatus = 200

                [pscustomobject]@{
                    'data' = [pscustomobject]@{
                        'id' = 12345
                    }
                }
            }

            & "$PSScriptRoot\script.ps1" @parameter_set | should -InvokeVerifiable
        }

        it 'passes the expected body to the API to update the password : <_.label>' -ForEach $parameterSets {
            Mock 'Invoke-RestMethod' -ParameterFilter {
                ($Body -replace '\s') -eq '{"data":{"attributes":{"password":"passwordhere"},"type":"passwords"}}'
            } -Verifiable -MockWith {

                $script:respStatus = 200

                [pscustomobject]@{
                    'data' = [pscustomobject]@{
                        'id' = 12345
                    }
                }
            }

            & "$PSScriptRoot\script.ps1" @parameter_set | should -InvokeVerifiable
        }

    }

    Context 'when the requested password does not exist' {

        BeforeAll {
            Mock 'Invoke-RestMethod' -ParameterFilter {
                $Uri -eq "$EndpointUri/passwords?filter[name]=namehere"
            } -MockWith {

                $script:respStatus = 400

                [pscustomobject]@{
                    'errors' = [pscustomobject]@{
                        'detail' = 'Record not found'
                    }
                }
            }
        }

        It 'should throw the expected error message : <_.label>' -ForEach $parameterSets {
            {& "$PSScriptRoot\script.ps1" @parameter_set } | should -Throw -ExpectedMessage 'The requested password * was not found.'
        }

    }
}