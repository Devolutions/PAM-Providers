# JIRA Ticket Creation/Update Secret Propagation

## Overview

This secret propagation script is designed to create or update a JIRA issue when a password change occurs in the Devolutions Server PAM module. It integrates with JIRA's REST API to either create a new ticket or update an existing one, providing a seamless way to track password changes and notify relevant parties through the JIRA platform.

## Features

- Creates a new JIRA issue or updates an existing one based on the provided parameters
- Supports various JIRA issue types (Task, Bug, Story, Epic, Subtask, Incident, Service Request, Change, Problem)
- Allows setting or updating the issue status (To Do, In Progress, Done)
- Automatically adds a description noting the user whose password has changed
- Validates project key and issue type availability before creating/updating the issue
- Handles API authentication securely using a JIRA API token

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

- PowerShell 7.0 or later installed on the system running the script. You can download it from the official PowerShell GitHub repository: https://github.com/PowerShell/PowerShell
- Access to a JIRA instance with appropriate permissions to create and update issues
- A JIRA API token for authentication. You can create one by following the official Atlassian documentation: https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
- The project key for the JIRA project where issues will be created/updated
- Knowledge of the available issue types and statuses in your JIRA project

## Properties

| Property       | Description                                            | Mandatory | Example                           |
|----------------|--------------------------------------------------------|-----------|-----------------------------------|
| SiteUrl        | The base URL of your JIRA instance                     | Yes       | `"https://your-domain.atlassian.net"` |
| JiraUsername   | The username or email for JIRA authentication          | Yes       | `"your-email@example.com"`        |
| ApiToken       | The JIRA API token for authentication (SecureString)   | Yes       | `(ConvertTo-SecureString "your-api-token" -AsPlainText -Force)` |
| ProjectKey     | The key of the JIRA project for issue creation/update  | Yes       | `"PROJ"`                          |
| IssueType      | The type of JIRA issue to create                       | Yes       | `"Task"`                          |
| UserName       | The username associated with the password change       | Yes       | `"john.doe"`                      |
| IssueSummary   | A brief summary or title for the JIRA issue            | Yes       | `"Password changed for user"`     |
| IssueKey       | The key of an existing issue to update (optional)      | No        | `"PROJ-123"`                      |
| Status         | The status to set for the issue (optional)             | No        | `"In Progress"`                   |