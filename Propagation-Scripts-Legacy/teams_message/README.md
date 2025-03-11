# Microsoft Teams Webhook Notification Propagation

## Overview

This secret propagation script is designed to send notifications to a Microsoft Teams channel via a webhook when a password change occurs in the Devolutions Server PAM module. It provides flexibility in sending simple text messages or more complex adaptive cards to keep your team informed about password change events.

## Features

- Sends notifications to Microsoft Teams channels using webhooks
- Supports simple text messages or complex adaptive cards
- Allows for dynamic content by replacing placeholders with actual usernames
- Provides options to specify message content directly or via JSON files
- Handles API errors and provides meaningful error messages

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

1. An active Microsoft Teams subscription with the following permissions:
   - Team Member or Team Owner role in the target team
   - Ability to create and manage channels within the team

   Note: Exact permission names and locations may vary based on your Microsoft 365 subscription and administrator settings.

2. A PowerAutomate workflow that will accept incoming webhooks.
    Learn how to set a workflow up: https://office365itpros.com/2024/06/17/teams-post-to-channel-workflow/

3. (Optional) If using connector cards, knowledge of the connector card JSON structure.
   - Refer to the Microsoft documentation on creating connector cards: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using?tabs=cURL%2Ctext1

## Properties

| Property                  | Description                                                   | Mandatory | Example                           |
|---------------------------|---------------------------------------------------------------|-----------|-----------------------------------|
| WebhookUrl                | The URL of the Microsoft Teams webhook                        | Yes       | `"https://prod-65.westus.logic.azure.com:443/workflows..."` |
| UserName                  | The username associated with the password change              | Yes       | `"john.doe"`                      |
| Message                   | A simple text message to send (optional)                      | No        | `"Password changed for user"`     |
| ConnectorCardJsonFilePath | Path to a JSON file containing an adaptive card (optional)    | No        | `"C:\path\to\card.json"`          |
| ConnectorCardJson         | JSON string of an adaptive card (optional)                    | No        | `'{"type":"AdaptiveCard",...}'`   |

Note: Either `Message`, `ConnectorCardJsonFilePath`, or `ConnectorCardJson` must be provided.