# Windows Service Account Password Update Propagation

## Overview

This PowerShell script is designed for the Devolutions Server Privileged Access Management (PAM) module, specifically for password propagation purposes. It facilitates the secure update of Windows service account passwords across specified endpoints. The script ensures that service accounts running Windows services have their passwords updated in accordance with changes initiated from the PAM module, maintaining security and compliance.

## Features

- **Secure Password Handling**: Uses secure strings to manage passwords, ensuring they are not exposed in plain text during the process.
- **Remote Execution**: Capable of executing against remote Windows endpoints, allowing for centralized management of service account passwords.
- **Service Management**: Optionally restarts services after password updates to ensure continuous operation with the new credentials.
- **Flexible Targeting**: Can target specific services by name or update all services run by a specified account, providing flexibility in scope of password updates.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- PowerShell 5.1 or higher installed and available on target server.
- User connecting to the target server has local admin privileges on the target server.
- Windows remote management is available on the target server.
- For a local account on the target server, write `EndpointUserName` with its prefix: `.\admin` or `SERVER01\admin`. A bare local name such as `admin` is refused by WinRM ("A specified logon session does not exist", error 0x8009030d).
- If the connection fails with "Access is denied", the endpoint user is not a local administrator on the target. If it fails with "The user name or password is incorrect", check `EndpointPassword`.

You can run the included `prerequisites.tests.ps1` script against the target server(s) with intended user credentials to ensure all prereqs are met.

## Properties

| Property            | Description                                             | Mandatory | Example                |
|---------------------|---------------------------------------------------------|-----------|------------------------|
| `Endpoint`          | The target machine where the service account is located | Yes       | `"server.example.com"` |
| `EndpointUserName`  | The username used to authenticate to the endpoint       | Yes       | `"administrator"`      |
| `EndpointPassword`  | The password for EndpointUserName as a secure string    | Yes       | SecureString           |
| `AccountUserName`   | The username of the service account, without domain (use `AccountUserNameDomain` for the domain) | Yes       | `"svc-sql"`     |
| `NewPassword`       | The new password for the service account as a secure string | Yes   | SecureString           |
| `ServiceName`       | The name of the service(s) to update, comma-separated for multiple services | No | `"Service1, Service2"` |
| `RestartService`    | Whether to restart the service(s) after updating the password | No | `yes` |