The Azure Key Vault (AKS) provider was last tested on **05/20/2024** and against Devolutions Server (DVLS) version **v2024.1.14.0**. The provider allows you to:

- Import AKS Secrets
- Rotate AKS Secret Values

## Prerequisites

You must have a previously created Azure Key Vault to manage with the Devolutions Server Privileged Access Module (PAM) solution.

> The PowerShell modules listed below are the required version to install. Newer versions will not work correctly at this time.

- [**Az.Accounts** - 2.16.0](https://www.powershellgallery.com/packages/Az.Resources/)

    ```PowerShell
    Install-Module -Name 'Az.Accounts' -Scope 'AllUsers' -RequiredVersion '2.16.0'
    ```

- [**Az.KeyVault** - 5.2.1](https://www.powershellgallery.com/packages/Az.KeyVault/)

  ```PowerShell
  Install-Module -Name 'Az.KeyVault' -Scope 'AllUsers' -RequiredVersion '5.2.1'
  ```

## Registering an Azure Active Directory Application for Service Principal Access

1. Navigate to **Microsoft Entra ID → App registrations** in the Microsoft Azure Portal. Once there, click the **New registration** button.

    ![Register a New App Registration](../../Images/azure-key-vault/akv-01-register-new-application.png)

2. Enter a name for the application. In this example, the application is named *AppAzureKeyVaultImageServicePrincipal*. All other values are left as their defaults.

    ![Enter App Registration Details](../../Images/azure-key-vault/akv-02-register-new-application-2.png)

3. Once created, click on the newly created application.

    ![Select Newly Registered Application](../../Images/azure-key-vault/akv-03-select-application-registration.png)

4. Navigate to **Certificates & secrets** section, select the **Client secrets** tab, and click the **New client secret** button.

    ![Create New Client Secret](../../Images/azure-key-vault/akv-04-new-client-secret.png)

5. Here the defaults of 180 days are used and, in this example a description of **PasswordAccessKeyVault**.

    ![New Client Secret Details](../../Images/azure-key-vault/akv-05-add-new-secret.png)

    ![Result of Creating a New Client Secret](../../Images/azure-key-vault/akv-06-new-client-created.png)

6. Navigate to **Azure Portal → Key vaults → "Your Key Vault" → Access configuration**. Ensure that the option for **Azure role-based access control (recommended)** is selected.

    ![Configure Permission Model](../../Images/azure-key-vault/akv-07-configure-permission-model.png)

7. Next, navigate to **Access Control (IAM)** and click on the **Add** button and choose **Add role assignment**.

    ![Configure Permission Model](../../Images/azure-key-vault/akv-08-add-role-assignment.png)

8. You will add two different IAM roles to your previously created Azure app. Filter by _Key Vault_ and choose the first role of **Key Vault Reader** and click the **Next** button.

    ![Add Key Vault Reader IAM Role](../../Images/azure-key-vault/akv-09-add-key-vault-reader.png)

9. Choose to assign access to a user, group, or service principal and click the **Select members** link. Enter and select your previously created service principal.

    ![Assign Member to Key Vault Reader](../../Images/azure-key-vault/akv-10-add-member-reader.png)

10. Once added, click **Review + assign**, and again, to confirm the selection.

    ![Confirm Key Vault Reader Role](../../Images/azure-key-vault/akv-11-confirm-key-vault-reader.png)

11. With the first permission added once again, click on the **Add** button and choose **Add role assignment**. filter by _Key Vault_ and choose the second role of **Key Vault Secrets Officer** and click the **Next** button.

    ![Add Key Vault Office IAM Role](../../Images/azure-key-vault/akv-12-add-key-vault-secrets-officer.png)

12. As before, select your previously created service principal and once added, review and assign to finish the selection.

13. Once completed, you will see both roles added to your service principal.

    ![Added IAM Roles](../../Images/azure-key-vault/akv-13-configured-iam-roles.png)

## Importing the Azure Key Vault PAM Provider JSON

An included `Azure Key Vault.json` file is located in the repository that creates the PAM Provider for you.

## Manually Setting Up the Azure Key Vault PAM Provider

Now that the Azure Key Vault is setup for use with the Devolutions Server PAM module, read on to configure PAM itself for use with the module.

1. Launch the Devolutions Server web portal, and navigate to **Administration → Privileged Access**.

    ![Open DVLS Portal Privileged Access](../../Images/azure-key-vault/akv-14-dvls-portal-administration.png)

2. Click the **Providers** button.

    ![Open DVLS Portal Providers](../../Images/azure-key-vault/akv-15-dvls-portal-privileged-access.png)

3. Click the **Template** button.

    ![Open DVLS Portal Provider Templates](../../Images/azure-key-vault/akv-16-dvls-portal-template.png)

4. Click the **Add** button.

    ![Create New PAM Provider Template](../../Images/azure-key-vault/akv-17-dvls-portal-template-add.png)

5. On the General tab, enter a name and check the Password rotation, Heartbeat, and Account discovery checkboxes.

    ![Enter PAM Provider General Details](../../Images/azure-key-vault/akv-18-template-general.png)

6. On the Provider Properties section, add the following (spelling and spacing matters):

   1. `TenantID` as a **Mandatory** String property.
   2. `ApplicationID` as a **Mandatory** String property.
   3. `Password` as a **Mandatory** Password property.
   4. `KeyVaultName` as a **Mandatory** String property.

      ![Enter Provider Details](../../Images/azure-key-vault/akv-19-template-provider.png)

7. On the Account Properties section, add the following (spelling and spacing matters):

   1. `Name` as a **Mandatory** Username property.
   2. `Secret` as a **Mandatory** Password property.
   3. `ID` as a **Mandatory** Unique Identifier property (this may be simply renaming the existing property). This property is also only used during discovery to ensure uniqueness.

      ![Enter Account Details](../../Images/azure-key-vault/akv-20-template-account.png)

8. On the Password Rotation section, add the following (spelling, spacing, and mapping matters):

   1. `TenantID` from **Provider** and mapped to `TenantID`.
   2. `ApplicationID` from **Provider** and mapped to `ApplicationID`.
   3. `Password` from **Provider** and mapped to `Password`.
   4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.
   5. `Name` from **Account** and mapped to `Name`.

      ![Enter Password Rotation Mapping](../../Images/azure-key-vault/akv-21-template-password-rotation.png)

9. Scroll down to the bottom of the Password Rotation section and click the **Edit** button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageResetPassword.ps1*

    ![Enter Password Rotation Code](../../Images/azure-key-vault/akv-22-template-password-rotation-code.png)

10. On the Heartbeat section, add the following (spelling, spacing, and mapping matters):

    1. `TenantID` from **Provider** mapped to `TenantID`.
    2. `ApplicationID` from **Provider** mapped to `ApplicationID`.
    3. `Password` from **Provider** and mapped to `Password`.
    4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.
    5. `Name` from **Account** and mapped to `Name`.
    6. `Secret` from **Account** mapped to `Secret`.

    ![Enter Heartbeat Details](../../Images/azure-key-vault/akv-23-template-heartbeat.png)

11. Scroll down to the bottom of the Heartbeat section and click the **Edit** button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageHeartbeat.ps1*

    ![Enter Heartbeat Code](../../Images/azure-key-vault/akv-24-template-heartbeat-code.png)

12. On the Account Discovery section, add the following (spelling, spacing, and mapping matters):

    1. `TenantID` from **Provider** mapped to `TenantID`.
    2. `ApplicationID` from **Provider** mapped to `ApplicationID`.
    3. `Password` from **Provider** and mapped to `Password`.
    4. `KeyVaultName` from **Provider** and mapped to `KeyVaultName`.

    ![Enter Account Discovery Details](../../Images/azure-key-vault/akv-25-template-account-discovery.png)

13. Scroll down to the bottom of the Heartbeat section and click on the Edit button to paste in the script located here in the repository: *PAM-Providers/Providers/Azure Key Vault/Script/AzureKeyVaultImageAccountDiscovery.ps1*

    ![Enter Account Discovery Code](../../Images/azure-key-vault/akv-26-template-account-discovery-code.png)

14. Finally, click the **Save** button.

15. Navigate to **Administration → Privileged Access → Providers** and click the **+** (plus) button to add the newly created Azure Key Vault provider.

    ![Add New Provider](../../Images/azure-key-vault/akv-27-add-provider-template.png)

16. Click on the **AnyIdentity** section and the **Azure Key Vault** provider.

    ![Select AnyIdentity Provider](../../Images/azure-key-vault/akv-28-select-anyidentity-provider.png)

17. Enter a **Name** for the Provider, here **Azure Key Vault** is used. Scroll down and enter the **TenantID** (Azure), **ApplicationID** (Azure Application Registration ID property), **Password**, and **KeyVaultName**. Check the options to **"Add PAM vault"** and **"Add Scan Configuration"**. Finally, click the **Save** button.

    ![Enter Template Details](../../Images/azure-key-vault/akv-29-enter-template-settings.png)

18. The **Scan configuration** modal will show, enter a **Name** and click the **OK** button to start the scan.

    ![Enter Template Details](../../Images/azure-key-vault/akv-30-enter-scan-settings.png)

19. Navigate to **Administration → Privileged Access → Account Discovery** and once the scan has completed, click the number contained in the results field.

    ![View Scan Results](../../Images/azure-key-vault/akv-31-provider-scan.png)

20. Check the boxes next to each secret to import and click the blue import button in the upper right.

    ![Import Scan Results](../../Images/azure-key-vault/akv-32-provider-scan-import.png)

21. Change the **Path** to the PAM vault to import into and click the **OK** button to import and manage the found accounts. You may not want to reset on import, if the key vault secrets are currently in use.

    ![Finalize Importing Scan Results](../../Images/azure-key-vault/akv-33-confirm-account-import.png)