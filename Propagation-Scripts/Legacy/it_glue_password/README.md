# ITGlue Password Propagation

## Overview

This script is designed for the purpose of password propagation within the ITGlue platform, as part of the overall Devolutions Server Privileged Access Management (PAM) module. It automates the process of resetting passwords for specified entities in ITGlue, thereby ensuring that password changes are propagated promptly and securely across the platform. This script supports operations against ITGlue's API to fetch and update passwords for various resources.

## Features

- **Secure Password Handling:** Utilizes SecureString for password encryption and decryption to enhance security.
- **Dynamic Endpoint Support:** Can be configured to work with any ITGlue API endpoint by specifying the Endpoint URI.
- **Comprehensive Error Handling:** Implements try-catch blocks for robust error management and clear error messages.
- **Flexible HTTP Method Support:** Supports various HTTP methods (GET, POST, PATCH, DELETE) for API interaction.
- **Automated Password Update:** Fetches and updates passwords based on the name, ensuring the new password is applied correctly.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- PowerShell 7 or higher.
- Access to ITGlue API with a valid API key -  The process for obtaining an API key for ITGlue can typically be found in the ITGlue documentation or developer portal. A step-by-step guide to generating an API key is [provided by ITGlue](https://helpdesk.kaseya.com/hc/en-gb/articles/4407484149265-Getting-started-with-the-IT-Glue-API).
- The necessary permissions to update passwords in ITGlue - The specific permissions needed will depend on the actions the script performs. For updating passwords, you will need permissions that allow you to read and write password entries in ITGlue. This information can often be found in the permissions or roles management section of the ITGlue documentation or help center. For detailed guidance on managing roles and permissions in ITGlue, check out the ITGlue Knowledge Base and search for permissions management related articles.

## Properties

| Property         | Description                                              | Mandatory | Example                    |
|------------------|----------------------------------------------------------|-----------|----------------------------|
| `EndpointApiKey` | The API key for authenticating against the ITGlue API.   | Yes       | SecureString value         |
| `PasswordName`   | The name of the password entry to update in ITGlue.      | Yes       | `"ExamplePasswordName"`    |
| `NewPassword`    | The new password to set for the named entry.             | Yes       | SecureString value         |
| `EndpointUri`    | The base URI for the ITGlue API.                         | No        | `"https://api.itglue.com"` |

## Configuration

To use this script, follow these steps for configuration:

1. Ensure all prerequisites are met, including the installation of any necessary software and obtaining the required permissions.
2. Replace the placeholder values for `EndpointApiKey`, `PasswordName`, and `NewPassword` with the actual values specific to your ITGlue environment.
3. (Optional) If you need to target a different ITGlue API endpoint, modify the `EndpointUri` accordingly.
4. Run the script with the necessary parameters to propagate the password change in ITGlue.
