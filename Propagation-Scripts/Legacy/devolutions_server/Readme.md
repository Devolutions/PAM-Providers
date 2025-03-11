# Devolutions Server Password Propagation

## Overview

This script is designed for the purpose of password propagation within the Devolutions Server.

## Features


## Prerequisites


## Properties

| Property         | Description                                                                                                                                    | Mandatory | Example                       |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------|-----------|-------------------------------|
| `DevolutionsServerUrl`        | The Devolutions Server URL.                                                                                                       | Yes       | `"https://contoso.com/dvls"`  |
| `ApplicationKey`              | Application Key of the Application Identity created by an administrator in Devolutions Server.                                    | Yes       |                               |
| `ApplicationSecret`           | Application secret of the Application Identity created by an administrator in Devolutions Server.                                 | Yes       |                               |
| `VaultId`                     | Vault ID where the secret can be found. If vault ID is not provided, vault name will be used                                      | No        |                               |
| `VaultName`                   | Vault name used if the vault ID is not provided. The script will be more efficient with the vault ID.                             | No        |                               |
| `RunAsAccount`                | The script is ran within a powershell remote session on the localhost. The session will be opened with that account if provided   | No        |                               |
| `RunAsPassword`               | If RunAsAccount is provided, this parameter is the password of the account used to open the remote session.                       | No        |                               |
| `PSSessionConfigurationName`  | If not specified, "Powershell.7" is used as configuration name to open the powershell remote session.                             | No        |                               |