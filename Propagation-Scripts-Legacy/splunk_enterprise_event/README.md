# Splunk Password Change Event Propagation

## Overview

This secret propagation script sends a password change event to Splunk using the HTTP Event Collector (HEC). It is designed to work with the Devolutions Server PAM (Privileged Access Management) module, allowing you to log password change events in your Splunk instance for auditing and monitoring purposes.

## Features

- Sends password change events to Splunk using HEC
- Supports both HTTP and HTTPS protocols
- Configurable Splunk host, port, and event source
- Uses secure string for sensitive information like HEC token and new password
- Implements error handling and verbose logging
- Supports custom event data including timestamp and user information

## Prerequisites

Before using this script, ensure you meet the following prerequisites:

1. Splunk instance with HTTP Event Collector (HEC) enabled
   - To set up HEC, follow the Splunk documentation: [Use the HTTP Event Collector](https://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector)

2. PowerShell 7.0 or later installed on the system running the script
   - Download and install from: [Installing PowerShell on Windows](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows)

3. Network connectivity between the system running the script and the Splunk server

4. HEC token with necessary permissions to send events
   - Create a new token in Splunk Web: Settings > Data Inputs > HTTP Event Collector > New Token

## Properties

| Property       | Description                                            | Mandatory | Example                |
| -------------- | ------------------------------------------------------ | --------- | ---------------------- |
| `SplunkHost`   | Hostname or IP address of the Splunk server            | Yes       | `"splunk.example.com"` |
| `HECToken`     | Secure string containing the HEC token                 | Yes       | N/A (Secure String)    |
| `UserName`     | Username of the account for which password was changed | Yes       | `"john.doe"`           |
| `NewPassword`  | Secure string containing the new password (unused)     | No        | N/A (Secure String)    |
| `Source`       | Source of the event as it will appear in Splunk        | No        | `"DevolutionsPAM"`     |
| `Port`         | Port number for the Splunk HEC                         | No        | `8088`                 |
| `Protocol`     | Protocol to use for the connection (http or https)     | No        | `"https"`              |