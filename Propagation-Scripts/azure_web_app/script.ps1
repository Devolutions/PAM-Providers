<#
.SYNOPSIS
    Updates an environment variable (application setting) for an Azure Web App using Service Principal authentication.

.DESCRIPTION
    This script connects to a specified Azure tenant using a Service Principal, retrieves the current application settings of a given Web App within a resource group (and optional deployment slot), updates or adds a specified environment variable, and applies the changes.

.PARAMETER NewPassword
    The new password for the user. This is not used in the current script but is a required parameter for propagation scripts.

.PARAMETER TenantID
    The Entra ID Tenant ID.

.PARAMETER SubscriptionID
    The Entra ID Subscription ID.
  
.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the Web App.

.PARAMETER WebAppName
    The name of the Azure Web App.

.PARAMETER ApplicationID
    The Client ID of the Entra ID Application (Service Principal).

.PARAMETER ApplicationPassword
    The password or secret associated with the Entra ID Application (Service Principal).

.PARAMETER Value
    The value to set for the environment variable.

.PARAMETER Setting
    The name of the environment variable to add or update.

.PARAMETER Slot
    The deployment slot of the Web App (e.g., 'production', 'preview'). Defaults to 'production' if not specified.

.EXAMPLE
    .\Update-WebAppEnvVar.ps1 -TenantID "your-tenant-id" `
                              -SubscriptionID "your-subscription-id" `
                              -ResourceGroup "MyResourceGroup" `
                              -WebAppName "MyWebApp" `
                              -ApplicationID "your-application-id" `
                              -ApplicationPassword (ConvertTo-SecureString "YourPassword" -AsPlainText -Force) `
                              -Value "NewValue123" `
                              -Setting "MY_ENV_VAR" `
                              -Slot "preview"

.NOTES
    - Ensure that the Azure PowerShell (`Az`) module is installed.
    - The script converts the provided `SecureString` to plain text to set the environment variable. Handle sensitive information accordingly.
    - To view debug messages, run the script with the `-Debug` flag.
#>

[CmdletBinding()]
Param (
  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$TenantID,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$SubscriptionID,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$ResourceGroup,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$WebAppName,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$ApplicationID,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [SecureString]$ApplicationPassword,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$Value,

  [Parameter(Mandatory = $True)]
  [ValidateNotNullOrEmpty()]
  [String]$Setting,

  [Parameter(Mandatory = $False)]
  [ValidateNotNullOrEmpty()]
  [String]$Slot = "production",

  [Parameter()]
  [securestring]$NewPassword
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$currentExecutionPolicy = Get-ExecutionPolicy
if ($currentExecutionPolicy -ne 'RemoteSigned' -and $currentExecutionPolicy -ne 'Unrestricted') {
  Set-ExecutionPolicy 'RemoteSigned' -Scope 'Process' -Force
}

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationID, $ApplicationPassword

Try {
  Write-Debug "Connecting to Azure tenant: $TenantID using Service Principal."
  Connect-AzAccount -ServicePrincipal -TenantId $TenantID -Credential $Credential -Subscription $SubscriptionID -ErrorAction 'Stop'
  Write-Debug "Successfully connected to Azure."
}
Catch {
  Write-Error "Failed to Connect to Azure: $_"
  Exit 1
}

Try {
  Write-Debug "Setting subscription context to Subscription ID: $SubscriptionID."
  Set-AzContext -SubscriptionId $SubscriptionID -ErrorAction 'Stop'
  Write-Debug "Subscription context set successfully."
}
Catch {
  Write-Error "Failed to set subscription context: $_"
  Exit 1
}

Try {
  Write-Debug "Retrieving Web App: $WebAppName in Resource Group: $ResourceGroup with Slot: $Slot."
  $webApp = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $WebAppName -ErrorAction 'Stop'

  if (-not $webApp) {
    Throw "Web App '$WebAppName' not found in Resource Group '$ResourceGroup' with Slot '$Slot'."
  }
  Write-Debug "Successfully retrieved Web App '$WebAppName'."
}
Catch {
  Write-Error "Failed to Retrieve Web App: $_"
  Exit 1
}

Try {
  Write-Debug "Fetching current application settings."
  $appSettings = (Get-AzWebAppSlot -ResourceGroupName $ResourceGroup -Name $WebAppName -Slot $Slot).SiteConfig.AppSettings

  $appSettingsHashtable = @{}
  foreach ($settingItem in $appSettings) {
    $appSettingsHashtable[$settingItem.Name] = $settingItem.Value
  }
  Write-Debug "Current application settings retrieved."
}
Catch {
  Write-Error "Failed to Retrieve Application Settings: $_"
  Exit 1
}

Write-Debug "Updating setting '$Setting'."
$appSettingsHashtable[$Setting] = $Value

Try {
  Write-Debug "Applying updated application settings."
  Set-AzWebAppSlot -ResourceGroupName $ResourceGroup -Name $WebAppName -AppSettings $appSettingsHashtable -Slot $Slot
  Write-Debug "Successfully updated application settings."
}
Catch {
  Write-Error "Failed to Apply Updated Application Settings: $_"
  Exit 1
}

Write-Debug "Environment variable '$Setting' has been successfully updated for Web App '$WebAppName' in Slot '$Slot'."
 