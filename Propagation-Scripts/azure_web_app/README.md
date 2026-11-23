# Azure Web App Propagation Script

## Overview

The Azure Web App Environment Variable Update Script is a PowerShell tool designed to automate the process of updating application settings (environment variables) for Azure Web Apps. Utilizing Service Principal authentication, this script ensures secure and efficient updates to your Web App's configuration, supporting deployment slots for more granular control.

## Features

- Secure Authentication: Connects to Azure using Service Principal credentials.
- Environment Variable Management: Adds or updates specified application settings for your Web App.
- Deployment Slot Support: Targets specific deployment slots (e.g., production, preview).
- Error Handling: Provides detailed error messages and logging for troubleshooting.
- Debugging Support: Run the script with the -Debug flag to view detailed operation logs.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

1. The Azure PowerShell (`Az`) module installed:
   - To install the Az module: `Install-Module -Name Az -AllowClobber -Scope CurrentUser`
   - For more information: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps

2. An Entra ID (Azure AD) tenant with the necessary permissions.
   - If you don't have an Entra ID tenant, create one: https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant

3. A service principal in your Entra ID tenant:
   - An Entra ID Service Principal with sufficient permissions to manage Web Apps.
   - How to create a Service Principal: https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal

4. The following information from your Entra ID tenant and registered application:
   - Tenant ID
   - Subscription ID
   - Application ID
   - Application Secret/Password

## Properties

| Parameter           | Description                                                | Mandatory | Default     | Example                                      |
|---------------------|------------------------------------------------------------|-----------|------------|----------------------------------------------|
| TenantID            | The Azure Tenant ID                                        | Yes       |            | "1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p"        |
| SubscriptionID      | The Azure Subscription ID                                  | Yes       |            | "2b3c4d5e-6f7g-8h9i-0j1k-2l3m4n5o6p7q"        |
| ResourceGroup       | The name of the Azure Resource Group containing the Web App| Yes       |            | "MyResourceGroup"                             |
| WebAppName          | The name of the Azure Web App                              | Yes       |            | "MyWebApp"                                    |
| ApplicationID       | The Client ID of the Azure AD Application (Service Principal)| Yes     |            | "abcdef12-3456-7890-abcd-ef1234567890"        |
| ApplicationPassword | The secret associated with the Azure AD Application        | Yes       |            | (SecureString)                                |
| Value               | The value to set for the environment variable              | Yes       |            | "NewValue123"                                 |
| Setting             | The name of the environment variable to add or update      | Yes       |            | "MY_ENV_VAR"                                  |
| Slot                | The deployment slot of the Web App                         | No        | production | "staging"                                     |
| NewPassword         | Required for propagation scripts but not used in script    | No        |            | (SecureString)                                |

## Configuration

To use this script within the Devolutions Server PAM module:

1. Import the script into your Devolutions Server environment.
2. Create a new Privileged Account Entry in the PAM module.
3. Associate this script with the account entry for password propagation.
4. Configure the script parameters in the PAM module, mapping them to the appropriate fields in your privileged account entry.
5. Set up a password change schedule or trigger as per your organization's security policies.

For detailed instructions on configuring propagation scripts in Devolutions Server, refer to the official documentation: https://docs.devolutions.net/pam/server/propagation-scripts/

## Troubleshooting

If you encounter issues while using this script:

1. Ensure the Azure PowerShell (`Az`) module is installed and updated.
2. Check that the provided Tenant ID, Subscription ID, Application ID, and Application Secret are correct and have the necessary permissions.
3. Verify that the Resource Group and Web App name exist in your Azure subscription.
4. Ensure the Service Principal has the necessary permissions to modify the Web App.
5. If using a custom slot, verify that the slot exists.
6. Review the script's output and error messages by running with the `-Debug` flag.
7. Consult the Devolutions Server logs for any PAM module-specific errors.

If problems persist, contact Devolutions support or consult the community forums for assistance.

## Additional Resources

- [Devolutions Server Documentation](https://docs.devolutions.net/server/)
- [Azure Web Apps Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [Entra ID (Azure AD) Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
