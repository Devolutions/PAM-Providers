## Prerequisites

The following PowerShell Modules are required. These modules must be installed and accessible to the PowerShell installation on the system hosting the Devolutions Server (DVLS) installation. There is a 5.x version of PowerShell embedded within DVLS that must have access to the PowerShell modules, hence the need to install the modules for the entire system.

- **Az.Accounts** 2.10.3 or higher - `Install-Module -Name Az.Accounts -Scope AllUsers`
- **Az.KeyVault** 4.9.0 or higher - `Install-Module -Name Az.KeyVault -Scope AllUsers`
- **Az.Resources** 6.5.1 or higher (Optional for setup script) - `Install-Module -Name Az.Resources -Scope AllUsers`

## Registering an Azure Active Directory Application for Service Principal Access

1. Navigate to **Azure Active Directory → App registrations** in the Azure Portal. Once there, click the **New registration** button.

    ![Register a New App Registration](../../Images/azure-key-vault/akv-01-register-new-application.png)

2. Enter a name for the application. In this example, the application is named *AppAzureKeyVaultImageServicePrincipal*. All other values are left as their defaults.

    ![Enter App Registration Details](../../Images/azure-key-vault/akv-02-register-new-application-2.png)

3. Once created, click on the newly created application.

    ![Select Newly Registered Application](../../Images/azure-key-vault/akv-03-select-application-registration.png)

4. Navigate to the **Certificates & secrets** section, click the **Client secrets** tab, and click the **New client secret** button.

    ![Create New Client Secret](../../Images/azure-key-vault/akv-04-new-client-secret.png)

5. Here the defaults of 180 days are used and, in this example a description of **PasswordAccessKeyVault**.

    ![New Client Secret Details](../../Images/azure-key-vault/akv-05-add-new-secret.png)

    ![Result of Creating a New Client Secret](../../Images/azure-key-vault/akv-06-new-client-created.png)

6. Navigate to **Azure Portal → Key Vaults → "Vault Name (Devolutions)" → Access configuration**. Ensure that the option for **Vault access policy** is selected.

    ![Configure Permission Model](../../Images/azure-key-vault/akv-07-configure-permission-model.png)

7. Next, click on **Access policies** and the **Create** button.

    ![Create Access Policy](../../Images/azure-key-vault/akv-08-create-access-policy.png)

8. Add only the necessary permissions, which are Get and List for Key permissions, and Get, List, and Set for Secret permissions. Click the **Next** button.

    ![Select Permissions for Access Policy](../../Images/azure-key-vault/akv-09-select-access-policy-permissions.png)

9. Locate the previously created application in Azure Active Directory and select the application.

    ![Select Access Policy Principal](../../Images/azure-key-vault/akv-10-select-access-policy-principal.png)

10. Leave all defaults for the **Application** section and click the **Next** button.

    ![Select Application Access Policy Defaults](../../Images/azure-key-vault/akv-11-access-policy-applicaition-defaults.png)

11. Finally, click the **Create** button on the **Review + create** section to finalize the Access Policy creation.

    ![Create the Access Policy](../../Images/azure-key-vault/akv-12-access-policy-creation.png)

## Creating an Azure Active Directory Application, Service Principal, and Access Policy via the PowerShell Az Module

An alternative method of creating the relevant pieces for the Devolutions Server PAM module to connect to Azure Key Vault is through the Az PowerShell module. An example script is shared below. Modify the initial variables to account for your environment.

```powershell
# Ensure that Tls12 is used to connect for all API functions.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Modify these variables to reflect your operational needs.
$ApplicationName = 'AppForServicePrincipalKeyVault'
$KeyVault        = 'Devolutions'
$ResourceGroup   = 'Devolutions'
$TenantId        = 'MyTenantID'

# These are the minimum necessary versions, as tested with this code.
$ModulesToImport = @{
  'Az.Accounts'  = '2.10.3'
  'Az.KeyVault'  = '4.9.0'
  'Az.Resources' = '6.5.1'
}

# If your minimum version is older, run Update-Module -Name 'Az'
$ModulesToImport.GetEnumerator() | ForEach-Object {
  Try {
    Import-Module -Name $PSItem.Key -MinimumVersion $PSItem.Value -ErrorAction 'Stop'
  } Catch {
    Write-Error ("Failed to Import Module: {0}" -F $Error[0].Exception.ToString())
    Exit
  }
}

Try {
  $Account = Connect-AzAccount -TenantId $TenantId -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Connect to Azure: {0}" -F $Error[0].Exception.ToString())
  Exit
}

Try {
  $Application = New-AzADApplication -DisplayName $ApplicationName -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Create AD Application: {0}" -F $Error[0].Exception.ToString())
  Exit
}

# Each Azure Application Credential is time-limited.
# The default Start Date is Today, and the default End Date is 1 Year from the time of creation.
# Modify these values with the -StartDate and -EndDate parameters.
Try {
  $ApplicationSecret = $Application | New-AzADAppCredential -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Create AD Application: {0}" -F $Error[0].Exception.ToString())
  Exit
}

# Modify Key Vault Access Configuration for Vault Access Policy, and not RBAC.
Try {
  Get-AzKeyVault -VaultName $KeyVault -ResourceGroupName $ResourceGroup -ErrorAction 'Stop' | Update-AzKeyVault -EnableRbacAuthorization $False -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Update Azure Key Vault Access Configuration: {0}" -F $Error[0].Exception.ToString())
  Exit
}

$Params = @{
  'VaultName'            = $KeyVault
  'ObjectId'             = $Application.Id
  'PermissionsToKeys'    = @('get','list')
  'PermissionsToSecrets' = @('get','list','set')
}

Try {
  $AccessPolicy = Set-AzKeyVaultAccessPolicy @Params -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Add Access Policy: {0}" -F $Error[0].Exception.ToString())
}
```

## Importing the Azure Key Vault PAM Provider JSON

> Functionality to import a PAM Provider via a JSON template is not yet released, as of version **2022.3.13.0**.

Instead of manually creating the PAM Provider, an included `Azure Key Vault.json` file is located in the repository that creates the PAM Provider for you.

## Manually Setting Up the Azure Key Vault PAM Provider

Now that the Azure Key Vault is setup for use with the Devolutions Server PAM module, read on to configure PAM itself for use with the module.

1. Launch the Devolutions Server web portal, and navigate to **Administration → Privileged Access**.

    ![Open DVLS Portal Privileged Access](../../Images/azure-key-vault/akv-17-dvls-portal-administration-2.png)

2. Click the **Providers** button.

    ![Open DVLS Portal Providers](../../Images/azure-key-vault/akv-18-dvls-portal-privileged-access-2.png)

3. Click the **Template** button.

    ![Open DVLS Portal Provider Templates](../../Images/azure-key-vault/akv-19-dvls-portal-template-2.png)

4. Click the **Add** button.

    ![Create New PAM Provider Template](../../Images/azure-key-vault/akv-20-dvls-portal-template-add.png)

5. On the General tab, enter a name and check the Password rotation, Heartbeat, and Account discovery checkboxes.

    ![Enter PAM Provider General Details](../../Images/azure-key-vault/akv-21-template-general.png)

6. On the Provider Properties section, add the following (spelling and spacing matters):

   1. `TenantID` as a **Mandatory** String property.

   2. `ApplicationID` as a **Mandatory** String property.

   3. `Password` as a **Mandatory** Sensitive Data property.

   4. `KeyVaultName` as a **Mandatory** String property.

      ![Enter Provider Details](../../Images/azure-key-vault/akv-22-template-provider.png)

7. On the Account Properties section, add the following (spelling and spacing matters):

   1. `Name` as a **Mandatory** Username property.

   2. `Secret` as a **Mandatory** Password property.

   3. `ID` as a **Mandatory** Unique Identifier property (this may be simply renaming the existing property).

      ![Enter Account Details](../../Images/azure-key-vault/akv-23-template-account.png)

8. On the Password Rotation section, add the following (spelling, spacing, and mapping matters):

   1. `TenantID` from **Provider** and mapped to `TenantID`.

   2. `ApplicationID` from **Provider** and mapped to `ApplicationID`.

   3. `Password` from **Provider** and mapped to `Password`.

   4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.

   5. `Name` from **Account** and mapped to `Name`.

   6. `ID` from **Account** and mapped to `ID`.

      ![Enter Password Rotation Mapping](../../Images/azure-key-vault/akv-24-template-password-rotation.png)

9. Scroll down to the bottom of the Password Rotation section and click on the Edit button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageResetPassword.ps1*

    ![Enter Password Rotation Code](../../Images/azure-key-vault/akv-25-template-password-rotation-code.png)

10. On the Heartbeat section, add the following (spelling, spacing, and mapping matters):

    1. `TenantID` from **Provider** mapped to `TenantID`.
    2. `ApplicationID` from **Provider** mapped to `ApplicationID`.
    3. `Password` from **Provider** and mapped to `Password`.
    4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.
    5. `Name` from **Account** and mapped to `Name`.
    6. `Secret` from **Account** mapped to `Secret`.
    7. `ID` from **Account** and mapped to `ID`.

    ![Enter Heartbeat Details](../../Images/azure-key-vault/akv-26-template-heartbeat.png)

11. Scroll down to the bottom of the Heartbeat section and click on the Edit button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageHeartbeat.ps1*

    ![Enter Heartbeat Code](../../Images/azure-key-vault/akv-27-template-heartbeat-code.png)

12. On the Account Discovery section, add the following (spelling, spacing, and mapping matters):

    1. `TenantID` from **Provider** mapped to `TenantID`.
    2. `ApplicationID` from **Provider** mapped to `ApplicationID`.
    3. `Password` from **Provider** and mapped to `Password`.
    4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.

    ![Enter Account Discovery Details](../../Images/azure-key-vault/akv-28-template-account-discovery.png)

13. Scroll down to the bottom of the Heartbeat section and click on the Edit button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageAccountDiscovery.ps1*

    ![Enter Account Discovery Code](../../Images/azure-key-vault/akv-29-template-account-discovery-code.png)

14. Finally, click the **Save** button.

15. Navigate to **Administration → Privileged Access → Providers** and click the **+** (plus) button to add the newly created Azure Key Vault provider.

    ![Add New Provider](../../Images/azure-key-vault/akv-30-add-provider-template.png)

16. Click on the Custom section and the Azure Key Vault provider.

    ![Select Custom Provider](../../Images/azure-key-vault/akv-31-select-custom-provider.png)

17. Enter a Name for the Provider, here Azure Key Vault is used. Scroll down and enter the TenantID (Azure) and ApplicationID (Azure Application Registration ID property). Click the Save button.

    ![Enter Template Details Part One](../../Images/azure-key-vault/akv-32-enter-template-settings-1.png)

    ![Enter Template Details Part Two](../../Images/azure-key-vault/akv-33-enter-template-settings-2.png)

18. Navigate to **Administration → Privileged Access → Account Discovery** and once the scan has completed, click the number contained in the results field.

    ![View Scan Results](../../Images/azure-key-vault/akv-34-provider-scan.png)

19. Check the boxes next to each value to manage and click the blue import button in the upper right.

    ![Import Scan Results](../../Images/azure-key-vault/akv-35-provider-scan-2.png)

20. Leave the defaults, and click the **OK** button to import and manage the found accounts. You may not want to reset on import, if the key vault secrets are currently in use.

    ![Finalize Importing Scan Results](../../Images/azure-key-vault/akv-36-import-accounts.png)
