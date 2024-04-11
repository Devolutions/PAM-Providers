Describe 'Zapier webhook propagation script' {

    $mandatoryParameters = @{
        'ZapierWebhookUrl' = 'someurlhere'
        'Credential'       = 'bobjones'
        'NewPassword'      = (ConvertTo-SecureString -String 'newpasswordhere' -AsPlainText -Force)
    }

    $parameterSets = @(
        @{
            label         = 'standard webhook with credential'
            parameter_set = $mandatoryParameters
        }
        @{
            label         = 'webhook with credential and message'
            parameter_set = ($mandatoryParameters + @{
                    Message = 'somemessagehere'
                })
        }
    )

    BeforeAll {
        Mock 'Write-Output'
    }

    It 'has a README doc' {
        Test-Path "$PSScriptRoot\README.md" | Should -BeTrue
    }

    It 'has a prerequisites test script' {
        Test-Path "$PSScriptRoot\zapier_webhook.tests.ps1" | Should -BeTrue
    }

    It 'has a NewPassword parameter' {

        $scriptContent = Get-Content -Path "$PSScriptRoot\script.ps1" -Raw
        $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($scriptContent, [ref]$null, [ref]$null)

        $paramBlocks = $scriptAst.FindAll({
                param($ast) $ast -is [System.Management.Automation.Language.ParamBlockAst]
            }, $true)

        '$NewPassword' | Should -BeIn $paramBlocks.Parameters.Name.Extent.Text
    }

    It 'passes the expected URL to Invoke-RestMethod : <_.label>' -ForEach $parameterSets {
        
        Mock 'Invoke-RestMethod' -ParameterFilter {
            $ZapierWebhookUrl -eq $parameter_set.ZapierWebhookUrl
        } -Verifiable

        $null = & "$PSScriptRoot\script.ps1" @parameter_set | Should -InvokeVerifiable
    }

    It 'passes the expected credential to Invoke-RestMethod : <_.label>' -ForEach $parameterSets {
        
        Mock 'Invoke-RestMethod' -ParameterFilter {
            $Body.credential -eq $parameter_set.Credential
        } -Verifiable

        $null = & "$PSScriptRoot\script.ps1" @parameter_set | Should -InvokeVerifiable
    }

    It 'passes the expected message to Invoke-RestMethod : <_.label>' -ForEach $parameterSets.where({ $_.ContainsKey('message') }) {
        
        Mock 'Invoke-RestMethod' -ParameterFilter {
            $Body.message -eq $parameter_set.Message
        } -Verifiable

        $null = & "$PSScriptRoot\script.ps1" @parameter_set | Should -InvokeVerifiable
    }

    Context 'when Invoke-Restmethod returns an HTTP exception' {

        BeforeAll {
    
            Mock Invoke-RestMethod {
                $response = New-Object System.Net.Http.HttpResponseMessage(404)
                $response.Content = New-Object System.Net.Http.StringContent("The requested resource could not be found.") 

                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new($message, $response)
            }
        }
        

        It 'returns an expected error message : <_.label>' -ForEach $parameterSets {
            { & "$PSScriptRoot\script.ps1" @parameter_set } | Should -Throw '*Zapier query failed with status*'
        }
    }

    Context 'when the Invoke-Restmethod invocation is successful' {

        BeforeAll {
    
            Mock Invoke-RestMethod {
                $guid = New-Guid
                [pscustomobject]@{
                    attempt    = $guid
                    id         = $guid
                    request_id = $guid
                    status     = 'success'
                }
            }
        }
        

        It 'returns $true : <_.label>' -ForEach $parameterSets {
            & "$PSScriptRoot\script.ps1" @parameter_set | Should -BeTrue
        }
    }
}