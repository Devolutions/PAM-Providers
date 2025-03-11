[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [uri]$WebhookUrl,

    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter()]
    [string]$Message,

    [Parameter()]
    [string]$ConnectorCardJsonFilePath,

    [Parameter()]
    [string]$ConnectorCardJson,

    ## This is only a placeholder for AnyID and is not used
    [Parameter()]
    [securestring]$NewPassword
)

function invokeApiCall {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string]$method,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$body,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$headers
    )

    # Prepare parameters for the Invoke-RestMethod call
    $irmParams = @{
        Uri                = $WebhookUrl
        Body               = $body
        Headers            = $headers
        Method             = $method
        StatusCodeVariable = 'respStatus' # Capture the status code of the API response
        SkipHttpErrorCheck = $true
    }

    try {
        # Make the API call
        $response = Invoke-RestMethod @irmParams -ErrorAction Stop

        # Check the response status code
        if ($respStatus -notin (1,200, 202)) {
            throw "API call failed with status code $respStatus : $($response.error.message)"
        }
    }
    catch {
        throw "Error occurred while making API call: $_"
    }
}

try {
    if ($Message) {
        $body = ConvertTo-Json @{ text = $Message } -Compress
    } elseif ($ConnectorCardJsonFilePath) {
        $body = Get-Content -Path $ConnectorCardJsonFilePath -Raw | ConvertFrom-Json
    } elseif ($ConnectorCardJson) {
        $body = $ConnectorCardJson
    } else {
        throw "No valid message parameter provided"
    }
    if ($UserName) {
        $body = $body -replace '{{username}}', $UserName
    }
}
catch {
    throw "Error preparing message body: $_"
}

# Make the API call
invokeApiCall -method POST -body $body -headers @{"Content-Type" = "application/json"}
