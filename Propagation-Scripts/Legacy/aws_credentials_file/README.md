# AWS IAM Credentials Update Propagation

## Overview

This password propagation script is designed for the Devolutions Server Privileged Access Management (PAM) module to update AWS IAM credentials in a credentials file on a remote endpoint. It automates the process of updating the AWS IAM access key ID and secret access key for specified (or all) profiles within an AWS credentials file (or multiple). This ensures that AWS services and applications using these credentials remain operational after a credential update, aligning with security best practices for regular password rotation.

## Features

- **Selective Profile Updates:** Supports updating specific profiles by name within the AWS credentials file. If no profile name is specified, it updates all profiles matching the old IAM access key ID.
- **Flexible Credentials File Location:** Can update credentials in a specified file path or search for the credentials file across all user profiles on the endpoint.

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- Remote access permissions on the endpoint where the AWS credentials file is located.
- The AWS credentials file must be accessible by the user account used to connect to the endpoint.
- PowerShell remoting must be enabled and configured on the target endpoint.

You can run the included `prerequisites.tests.ps1` script against the target server(s) with intended user credentials to ensure all prereqs are met.

## Properties

| Property            | Description                                               | Mandatory | Example                                         |
|---------------------|-----------------------------------------------------------|-----------|-------------------------------------------------|
| `Endpoint`          | The endpoint (computer name or IP address)                | Yes       | `"server.example.com"`                          |
| `EndpointUserName`  | The username to connect to the endpoint                   | Yes       | `"admin"`                                       |
| `EndpointPassword`  | The password for the EndpointUserName in a secure string | Yes       | `(ConvertTo-SecureString "password" -AsPlainText -Force)` |
| `OldIAMAccessKeyId` | The old IAM access key ID to be replaced                  | Yes       | `"AKIAIOSFODNN7EXAMPLE"`                        |
| `NewIAMAccessKeyId` | The new IAM access key ID to update                       | Yes       | `"AKIAI44QH8DHBEXAMPLE"`                        |
| `NewPassword`       | The new IAM secret access key in a secure string format   | Yes       | `(ConvertTo-SecureString "newSecretAccessKey" -AsPlainText -Force)` |
| `ProfileName`       | The profile name(s) to update (optional)                  | No        | `"default"`                                     |
| `CredentialsFilePath` | The path to the AWS credentials file (optional)         | No        | `"C:\Users\Admin\.aws\credentials"`             |