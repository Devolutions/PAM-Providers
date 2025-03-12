[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ServiceNowInstance,

    [Parameter(Mandatory)]
    [string]$OAuthClientId,

    [Parameter(Mandatory)]
    [securestring]$OAuthClientSecret,

    [Parameter(Mandatory)]
    [string]$ServiceNowUsername,

    [Parameter(Mandatory)]
    [securestring]$ServiceNowUserPassword,

    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter()]
    [ValidatePattern('^(INC\d{7})?$')]
    [string]$IncidentNumber,

    [Parameter()]
    [string]$Description,

    [Parameter()]
    [string]$WorkNotes,

    [Parameter()]
    [ValidateRange(0,7)]
    [int]$State,

    ## This is only a placeholder for AnyID and is not used
    [Parameter()]
    [securestring]$NewPassword
)

Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]..."

$ErrorActionPreference = 'Stop'

# Function to obtain an access token from ServiceNow
function Get-ServiceNowAccessToken {
    [CmdletBinding()]
    param(
        # The refresh token to use for obtaining a new access token (optional)
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$RefreshToken
    )

    $apiUrl = "https://$ServiceNowInstance.service-now.com/oauth_token.do"

    $plainTextClientSecret = (New-Object PSCredential "user", $OAuthClientSecret).GetNetworkCredential().Password

    $params = @{
        Uri                = $apiUrl
        SkipHttpErrorCheck = $true
        Method             = 'POST'
        StatusCodeVariable = 'StatusCode'
        Body               = @{
            grant_type    = "password"
            client_id     = $OAuthClientId
            client_secret = $plainTextClientSecret
        }
    }

    if ($PSBoundParameters.ContainsKey('RefreshToken')) {
        $params.Body.grant_type = 'refresh_token'
        $params.Body.refresh_token = $RefreshToken
    } else {
        $params.Body.grant_type = 'password'
        $params.Body.username = $ServiceNowUsername
        $params.Body.password = (New-Object PSCredential "user", $ServiceNowUserPassword).GetNetworkCredential().Password
    }

    $response = Invoke-RestMethod @params
    if ($StatusCode -ne 200) {
        throw "Failed to generate access token. Error: $($response.error_description)"
    }

    $response
}

# Function to make API calls to ServiceNow
function Invoke-ServiceNowApi {
    [CmdletBinding()]
    param (
        # The endpoint to call
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,

        # The HTTP method to use (optional, defaults to GET)
        [ValidateSet('GET', 'POST', 'PATCH')]
        [string]$Method = 'GET',

        # The body to send with the request (optional)
        [Parameter()]
        [object]$Body
    )

    $uri = "https://$ServiceNowInstance.service-now.com/api/now/$Endpoint"
    $headers = @{
        'Authorization' = "Bearer $script:accessToken"
    }

    $params = @{
        Uri                = $uri
        Method             = $Method
        Headers            = $headers
        SkipHttpErrorCheck = $true
        StatusCodeVariable = 'StatusCode'
        ContentType        = 'application/json'
    }
    if ($Body) {
        $params['Body'] = ($Body | ConvertTo-Json)
    }

    $response = Invoke-RestMethod @params
    if ($StatusCode -notin 200, 201) {
        throw "API call failed with status code: $StatusCode, $($response.error.message) -- $($response.error.detail)"
    }
    $response
}
 
# Function to retrieve a specific incident from ServiceNow
function Get-ServiceNowIncident {
    [CmdletBinding()]
    param (
        # The incident number to retrieve
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$IncidentNumber
    )

    # Construct the query to find the incident by number
    $query = "number=$IncidentNumber"
    $endpoint = "table/incident?sysparm_query=$query&sysparm_limit=1"
    
    $incident = Invoke-ServiceNowApi -Endpoint $endpoint -Method 'GET'
        
    if ($incident.result.Count -gt 0) {
        $incident.result[0]
    }
}

# Function to update an existing incident in ServiceNow
function Update-ServiceNowIncident {
    [CmdletBinding()]
    param (
        # The ID of the incident to update
        [Parameter(Mandatory)]
        [string]$IncidentId,

        # The fields to update
        [Parameter(Mandatory)]
        [hashtable]$Fields
    )

    Invoke-ServiceNowApi -Endpoint "table/incident/$IncidentId" -Method 'PATCH' -Body $Fields
}

# Function to create a new incident in ServiceNow
function New-ServiceNowIncident {
    [CmdletBinding()]
    param (
        # The fields for the new incident
        [Parameter(Mandatory)]
        [hashtable]$Fields
    )

    Invoke-ServiceNowApi -Endpoint "table/incident" -Method 'POST' -Body $Fields
}

# Get the access token
$script:accessToken = (Get-ServiceNowAccessToken).access_token

# Prepare the fields for creating or updating an incident
$fields = @{
    short_description = "The username [$UserName]'s password has changed."
    description       = $Description
    work_notes        = $WorkNotes
}

## Not validated in the parameter because AnyID always passes a value of 0 if not provided in the AnyId prop script
if ($State -gt 0) {
    $fields.state = $State
}

# Remove any null values from the fields hashtable
$populatedFields = @{}
$fields.GetEnumerator() | Where-Object { $_.Value } | ForEach-Object { $populatedFields[$_.Key] = $_.Value }

# Ensure at least one field is provided
if ($populatedFields.Count -eq 0) {
    throw "No fields provided to create/update an incident."
}

# Update existing incident if provided, otherwise create a new one
if ($IncidentNumber) {
    $existingIncident = Get-ServiceNowIncident -IncidentNumber $IncidentNumber

    if ($existingIncident) {
        $null = Update-ServiceNowIncident -IncidentId $existingIncident.sys_id -Fields $populatedFields
    } else {
        throw "Incident $IncidentNumber not found"
    }
} else {
    $null = New-ServiceNowIncident -Fields $populatedFields
}

# Indicate success
$true