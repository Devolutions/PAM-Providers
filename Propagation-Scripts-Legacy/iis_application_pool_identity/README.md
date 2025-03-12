# IIS Application Pool Password Update Password Propagation

## Overview

This password propagation script is designed for use within the Devolutions Server Privileged Access Management (PAM) module to handle the secure and automated update of passwords for IIS Application Pool identities. It ensures that application pools using specific user accounts for their identity can have their passwords updated in line with changes managed by the PAM module, maintaining security and access control for web applications hosted on IIS.

## Features

- **Endpoint Connection**: Connects to a specified IIS server to manage application pool idenity passwords.
- **Application Pool Management**: Identifies and updates the password for application pools running under a specific user identity.
- **Flexible Targeting**: Can target a single application pool or multiple pools by specifying their names.
- **Secure Credential Handling**: Uses secure strings for password handling to ensure sensitive data is not exposed in plain text.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- IIS (Internet Information Services) must be installed and running on the target server.
- The WebAdministration PowerShell module should be available on the target server.
- Proper permissions to manage IIS and application pools must be granted to the user or account executing the script.
- PowerShell remoting should be enabled and configured if the script is run from a remote machine.

## Properties

| Property                          | Description                                          | Mandatory | Example                        |
|-----------------------------------|------------------------------------------------------|-----------|--------------------------------|
| `Endpoint`                        | The hostname or IP address of the target IIS server. | Yes       | `"server.example.com"`         |
| `EndpointUserName`                | The username for connecting to the IIS server.       | Yes       | `"administrator"`              |
| `EndpointPassword`                | The password for connecting to the IIS server.       | Yes       | *SecureString*                 |
| `ApplicationPoolIdentityUserName` | The username of the application pool identity.       | Yes       | `"AppPoolUser"`                |
| `NewPassword`                     | The new password for the application pool identity.  | Yes       | *SecureString*                 |
| `ApplicationPoolName`             | The name(s) of the application pool(s) to update.    | No        | `"AppPool1,AppPool2"`          |