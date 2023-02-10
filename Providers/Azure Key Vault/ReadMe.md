2 Modules are required. They must be installed on the powershell of the machine hosting the devolution server.
 - **Az.Accounts** 2.10.3 or higher
 - **Az.KeyVault** 4.9.0 or higher

You must use an Application ID to connect to your Azure Key Vault.
On your target Key Vault, you will to give you application the following right.

Secret Permission
 - Get
 - List
 - Set