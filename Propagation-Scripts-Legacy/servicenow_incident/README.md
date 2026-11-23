# ServiceNow Incident Creation/Update Secret Propagation

## Overview

This secret propagation script is designed to create or update a ServiceNow incident when a password change occurs in the Devolutions Server PAM module. It integrates with ServiceNow's REST API to either create a new incident or update an existing one, providing a seamless way to track password changes and notify relevant parties through the ServiceNow platform.

## Features

- Creates a new ServiceNow incident or updates an existing one based on the provided parameters
- Supports OAuth 2.0 authentication for secure API access
- Allows setting or updating incident fields such as short description, description, work notes, and state
- Automatically adds a short description noting the user whose password has changed
- Validates incident number format and state value before creating/updating the incident
- Handles API authentication securely using OAuth client credentials and user credentials

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- PowerShell 7.0 or later installed on the system running the script. You can download it from the official PowerShell GitHub repository: https://github.com/PowerShell/PowerShell
- Access to a ServiceNow instance with appropriate permissions to create and update incidents
- OAuth client credentials (Client ID and Client Secret) for your ServiceNow instance. You can create these by following the official ServiceNow documentation: https://docs.servicenow.com/bundle/paris-platform-administration/page/administer/security/task/t_CreateEndpointforExternalClients.html
- A ServiceNow user account with permissions to create and update incidents
- Knowledge of the available incident states in your ServiceNow instance

## Properties

| Property                | Description                                                   | Mandatory | Example                           |
|-------------------------|---------------------------------------------------------------|-----------|-----------------------------------|
| ServiceNowInstance      | The instance name of your ServiceNow deployment               | Yes       | `"your-instance"`                 |
| OAuthClientId           | The OAuth client ID for ServiceNow API authentication         | Yes       | `"your-client-id"`                |
| OAuthClientSecret       | The OAuth client secret (SecureString)                        | Yes       | `(ConvertTo-SecureString "your-client-secret" -AsPlainText -Force)` |
| ServiceNowUsername      | The username for ServiceNow authentication                    | Yes       | `"your-username"`                 |
| ServiceNowUserPassword  | The password for ServiceNow authentication (SecureString)     | Yes       | `(ConvertTo-SecureString "your-password" -AsPlainText -Force)` |
| UserName                | The username associated with the password change              | Yes       | `"john.doe"`                      |
| IncidentNumber          | The number of an existing incident to update (optional)       | No        | `"INC0010001"`                    |
| Description             | Additional description for the incident (optional)            | No        | `"Detailed information about the password change"` |
| WorkNotes               | Work notes to add to the incident (optional)                  | No        | `"Action taken: Password rotated"` |
| State                   | The state to set for the incident (optional, 0-7)             | No        | `2`                               |