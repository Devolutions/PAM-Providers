[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter(Mandatory)]
    [string]$Channel,

    [Parameter(Mandatory)]
    [securestring]$SlackOAuthToken,

    [Parameter(Mandatory)]
    [string]$WebhookUrl,

    [Parameter()]
    [string]$Message,

    ## Not used. Only here for AnyId
    [Parameter()]
    [securestring]$NewPassword
)

#region Functions

function decryptSecret ([securestring]$Secret) {
    # Decrypts a secure string
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted secret from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function invokeSlackApiCall {
    # Invokes an API call to Slack
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$RequestBody,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('POST')]
        [string]$Method = 'POST'
    )

    # Setup the headers for the API call, including the API key
    $headers = @{
        'Content-type' = 'application/json'
    }

    # Initialize parameters for Invoke-RestMethod
    $irmParams = @{
        Uri                = $WebhookUrl
        Method             = $Method # HTTP method (GET, POST, etc.)
        Headers            = $headers # Headers including the API key
        StatusCodeVariable = 'respStatus' # Capture the status code of the API response
        SkipHttpErrorCheck = $true
        Body               = ($RequestBody | ConvertTo-Json)
    }

    # Make the API call
    $response = Invoke-RestMethod @irmParams
    # If the response status code is not 200, throw the response as an error
    if ($respStatus -ne 200 -or $response -ne 'ok') {
        if ($response.errors) {
            throw $response.errors.detail
        } else {
            throw $response
        }
    }
}
#endregion

## This is useful to see what parameters DVLS passed to the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]..."

# Set the preference to stop the script on any errors encountered
$ErrorActionPreference = 'Stop'

if (-not $Message) {
    $Message = "User [$UserName] password has been reset."
} else {
    $Message = "User [$UserName] password has been reset : $Message"
}

$requestBody = @{
    'text' = $Message
    'channel' = $Channel
    'token' = (decryptSecret $SlackOAuthToken)
}

invokeSlackApiCall -RequestBody $requestBody