# Entra ID MFA Reset Propagation Script

## Overview

The Entra ID MFA Reset Propagation Script is a powerful tool designed to work within the Devolutions Server PAM (Privileged Access Management) module. This script allows for the automatic reset of multi-factor authentication (MFA) methods for specified Entra ID (formerly Azure AD) users. It's particularly useful in scenarios where organizational policies automatically re-add authentication methods, ensuring a clean slate for user authentication.

## Features

- Removes all non-password authentication methods for a specified user
- Integrates seamlessly with Devolutions Server PAM module
- Utilizes Microsoft Graph API for secure and efficient operations
- Supports organizational policies that automatically re-add authentication methods
- Provides detailed logging for troubleshooting and auditing purposes

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

1. PowerShell 7.0 or higher installed on the system running the script.
   - To install or update PowerShell, visit: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell

2. An Entra ID (Azure AD) tenant with the necessary permissions.
   - If you don't have an Entra ID tenant, create one: https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-access-create-new-tenant

3. An application registered in your Entra ID tenant with the following Microsoft Graph API permissions:
   - User.ReadBasic.All
   - UserAuthenticationMethod.ReadWrite.All
   - To register an application and grant permissions, follow: https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app

4. The following information from your Entra ID tenant and registered application:
   - Tenant ID
   - Client ID
   - Client Secret
   - Tenant Domain

5. Run the included `prerequisites.tests.ps1` script to ensure all prerequisites are met:
   ```powershell
   $clientSecret = ConvertTo-SecureString "YourClientSecret" -AsPlainText -Force
   .\prerequisites.tests.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret $clientSecret
   ```

## Properties

| Property       | Description                                            | Mandatory | Example                |
|----------------|--------------------------------------------------------|-----------|------------------------|
| UserName       | The username of the Entra ID user (without domain)     | Yes       | "johndoe"              |
| NewPassword    | The new password for the user (not used in this script)| Yes       | (SecureString)         |
| TenantId       | The ID of your Entra ID tenant                         | Yes       | "1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p" |
| ClientId       | The client ID of the registered application            | Yes       | "abcdef12-3456-7890-abcd-ef1234567890" |
| ClientSecret   | The client secret of the registered application        | Yes       | (SecureString)         |
| TenantDomain   | The domain name of your Entra ID tenant                | Yes       | "yourdomain.com"       |

## Configuration

To use this script within the Devolutions Server PAM module:

1. Import the script into your Devolutions Server environment.
2. Create a new Privileged Account Entry in the PAM module.
3. Associate this script with the account entry for password propagation.
4. Configure the script parameters in the PAM module, mapping them to the appropriate fields in your privileged account entry.
5. Set up a password change schedule or trigger as per your organization's security policies.

For detailed instructions on configuring propagation scripts in Devolutions Server, refer to the official documentation: https://docs.devolutions.net/server/privileged-access-management/password-propagation/

## Troubleshooting

If you encounter issues while using this script:

1. Ensure all prerequisites are met by running the `prerequisites.tests.ps1` script.
2. Check that the provided Tenant ID, Client ID, and Client Secret are correct and have the necessary permissions.
3. Verify that the user account specified exists in your Entra ID tenant.
4. Review the script's output and error messages for specific issues.
5. Consult the Devolutions Server logs for any PAM module-specific errors.

If problems persist, contact Devolutions support or consult the community forums for assistance.

## Additional Resources

- [Devolutions Server Documentation](https://docs.devolutions.net/server/)
- [Microsoft Graph API Documentation](https://docs.microsoft.com/en-us/graph/overview)
- [Entra ID (Azure AD) Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)