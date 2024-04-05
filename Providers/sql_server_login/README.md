# SQL Server Login AnyIdentity Provider

This SQL Server Login AnyIdentity provider is designed to integrate with the Devolutions Server PAM module to manage SQL Server login credentials. It enables automated account discovery and password rotation for SQL Server logins.

## Capabilities

This provider allows for:

- **Account Discovery**: Automated enumeration of SQL Server login accounts.
- **Heartbeat**: Validation that the passwords in Devolutions Server match those set on the SQL Server instance.
- **Password Rotation**: Automated update of SQL Server login passwords as per policy or on-demand.

## Prerequisites

Before using these scripts, ensure you meet the following prerequisites:

- Appropriate permissions on the SQL Server instance to query and modify login accounts.

You can run the included `sql_server_provider.prerequisites.tests.ps1` script against the SQL Server instance with intended user credentials to ensure all prerequisites are met.

## Account Discovery

The `account_discovery.ps1` script supports the discovery of SQL Server login accounts, enabling the Devolutions Server to manage these accounts effectively.

### Properties

| Property             | Description                                 | Mandatory | Example               |
|----------------------|---------------------------------------------|-----------|-----------------------|
| `SqlServerInstance`  | The SQL Server instance to connect to.      | Yes       | `"server.example.com"`|
| `SqlCredential`      | The PSCredential object for SQL authentication. | No    | `$(Get-Credential)`   |

## Heartbeat

The `heartbeat.ps1` script verifies that the passwords stored in Devolutions Server are synchronized with the SQL Server login passwords.

### Properties

| Property             | Description                                 | Mandatory | Example               |
|----------------------|---------------------------------------------|-----------|-----------------------|
| `SqlServerInstance`  | The SQL Server instance to connect to.      | Yes       | `"server.example.com"`|
| `SqlCredential`      | The PSCredential object for SQL authentication. | No    | `$(Get-Credential)`   |

## Password Rotation

The `password_rotation.ps1` script manages the rotation of SQL Server login passwords, ensuring compliance with security policies.

### Properties

| Property             | Description                                 | Mandatory | Example               |
|----------------------|---------------------------------------------|-----------|-----------------------|
| `SqlServerInstance`  | The SQL Server instance to connect to.      | Yes       | `"server.example.com"`|
| `SqlCredential`      | The PSCredential object for SQL authentication. | No    | `$(Get-Credential)`   |
| `NewPassword`        | The new password for the SQL login.         | Yes       | `"NewP@ssw0rd!"`      |


## Troubleshooting

- If the account discovery script does not return all expected accounts, verify that the SQL Server instance is accessible and that you have the necessary permissions.
- If password rotation fails, check for password complexity requirements or lockout policies that might be preventing the change.

## Additional Resources

For more information on managing SQL Server logins and PowerShell scripting, refer to the [official SQLServer module documentation](https://docs.microsoft.com/en-us/powershell/module/sqlserver/?view=sqlserver-ps).
