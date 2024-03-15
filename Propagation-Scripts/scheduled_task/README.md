# Scheduled Task Password Update Propagation

## Overview

This password propagation script is designed to automate the process of updating passwords for scheduled tasks on a remote Windows server. It fits into the overall Devolutions Server Privileged Access Management (PAM) module by ensuring that scheduled tasks continue to operate under the correct credentials after a password change, thus maintaining security and operational integrity.

## Features

- **Remote Execution:** Capable of connecting to and executing on one or many remote Windows servers.
- **Secure Credential Handling:** Uses secure strings for password handling to ensure that credentials are protected during transmission and execution.
- **Flexible Task Selection:** Allows for updating the password of all scheduled tasks running under a specified user account, or targeting specific tasks by name or path.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- PowerShell 5.1 or higher installed and available on target server.
- User connecting to the target server has local admin privileges on the target server.
- Windows remote management is available on the target server.

You can run the included `prerequisites.tests.ps1` script against the target server(s) with intended user credentials to ensure all prereqs are met.

## Properties

| Property            | Description                                                         | Mandatory | Example                             |
|---------------------|---------------------------------------------------------------------|:---------:|-------------------------------------|
| `Endpoint`          | The hostname or IP address of the target Windows server.            |    Yes    | `"server.example.com"`              |
| `EndpointUserName`  | The username for connecting to the endpoint.                        |    Yes    | `"adminUser"`                       |
| `EndpointPassword`  | The password for the endpoint user, as a secure string.             |    Yes    | `(ConvertTo-SecureString -String "Password123!" -AsPlainText -Force)` |
| `AccountUserName`   | The username of the account whose scheduled tasks are to be updated.|    Yes    | `"serviceAccount"`                  |
| `NewPassword`       | The new password for the account, as a secure string.               |    Yes    | `(ConvertTo-SecureString -String "NewPassword!" -AsPlainText -Force)` |
| `ScheduledTaskName` | (Optional) The name of a specific scheduled task to update.         |    No     | `"BackupTask"`                      |
| `ScheduledTaskPath` | (Optional) The path for specific scheduled tasks to be updated.     |    No     | `"\Maintenance\"`                 |
