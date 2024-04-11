<#
.SYNOPSIS
    Invokes a Zapier webhook to propagate password changes or send notifications.

.DESCRIPTION
    This script triggers a Zapier webhook to handle password propagation or send messages
    based on the parameters provided. It uses a POST request to send data including 
    credential details and an optional message to the specified Zapier webhook URL.

.PARAMETER ZapierWebhookUrl
    The URL of the Zapier webhook where the POST request will be sent.

.PARAMETER Credential
    The identifier for the credential that is subject to the propagation or notification.

.PARAMETER NewPassword
    The new secure password being propagated. This is currently NOT send to Zapier and is only
    here to work within DVLS constraints.

.PARAMETER Message
    Optional parameter to include a message in the payload sent to the Zapier webhook.

.EXAMPLE
    $securePassword = ConvertTo-SecureString "myNewPassword123" -AsPlainText -Force
    .\PropagationScript.ps1 -ZapierWebhookUrl 'https://hooks.zapier.com/hooks/catch/123456/abcde' `
                            -Credential 'User123' -NewPassword $securePassword `
                            -Message 'Password updated successfully'

    This example shows how to run the script with all parameters, including an optional message.
    It sends a POST request to the Zapier webhook with the credential identifier, the new password,
    and a success message.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ZapierWebhookUrl,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Credential,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Message
)

# Set the preference to stop the script on any error encountered during execution
$ErrorActionPreference = 'Stop'

# Output current script parameters and the username of the user executing the script for logging and debugging purposes
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]"

# Prepare parameters for Invoke-RestMethod, specifying the Zapier webhook URL and method as POST
$irmParams = @{
    Uri    = $ZapierWebhookUrl  # URL for the Zapier webhook endpoint
    Method = 'POST'             # HTTP method to be used for the webhook call
}

# Initialize payload with the credential that will be sent in the POST request
$payload = @{
    'credential' = $Credential  # The credential parameter, mandatory for the webhook data
}

# Conditionally add a message to the payload if provided in the script parameters
if ($PSBoundParameters.ContainsKey('Message')) {
    $payload.message = $Message  # Optional message to be included in the payload
}

# Assign the completed payload to the body of the HTTP request parameters
$irmParams.Body = $payload

# Try block to handle potential errors from the web request
try {
    # Execute the POST request to the Zapier webhook with the specified parameters and suppress the output
    $null = Invoke-RestMethod @irmParams
    # Return true to signify successful execution of the webhook call
    $true

    # Catch block specifically for handling HTTP response exceptions from the Invoke-RestMethod call
} catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    # Write a specific error message with the reason phrase from the HTTP response
    Write-Error -Message "Zapier query failed with status: $($_.Exception.Response.ReasonPhrase)"

    # General catch block for other types of exceptions that could occur during execution
} catch {
    # Rethrow the exception to be handled further up the call stack or to show a detailed error message
    throw $_
}
