# [Provider Name] AnyIdentity Provider

## Overview

[Provide a brief introduction to the AnyIdentity provider, including what it is and its primary use case within the Devolutions Server PAM module.]

## Capabilities

[Detail the capabilities of this AnyIdentity provider, such as account discovery, heartbeat monitoring, and password rotation. Include any unique features or benefits that distinguish this provider from others.]

## Account Discovery

- Describe how the provider supports discovering accounts automatically or manually. Describe what kind of accounts/secrets the script will discover and any unique ways the script enumerates accounts.

### Properties

| Property       | Description        | Mandatory | Example                |
| ----------------------------------- | --------- | ---------------------- |
| `PropertyName` | <description here> |    Yes    |  `"server.example.com"`|

## Heartbeat

- Explain the heartbeat mechanism, including how it verifies the current secret against the one stored in the PAM module.

### Properties

| Property       | Description        | Mandatory | Example                |
| ----------------------------------- | --------- | ---------------------- |
| `PropertyName` | <description here> |    Yes    |  `"server.example.com"`|

## Password Rotation

- Detail the process and mechanisms for password rotation, including any prerequisites or conditions that trigger a password change.

### Properties

| Property       | Description        | Mandatory | Example                |
| ----------------------------------- | --------- | ---------------------- |
| `PropertyName` | <description here> |    Yes    |  `"server.example.com"`|

## Requirements

[List any prerequisites or requirements needed to use this provider, such as specific software versions, permissions, or configurations. Instruct the user on how to run the associated prerequisites.tests.ps1 Pester tests]

## Troubleshooting

[Offer common troubleshooting tips or solutions to typical issues encountered with this provider.]

## Additional Resources

[Provide links to additional documentation, scripts, or forums related to the AnyIdentity provider. This can include official documentation, community contributions, or internal resources.]