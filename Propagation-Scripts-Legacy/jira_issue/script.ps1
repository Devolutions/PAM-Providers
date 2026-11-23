[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [Parameter(Mandatory)]
    [string]$JiraUsername,

    [Parameter(Mandatory)]
    [SecureString]$ApiToken,

    [Parameter(Mandatory)]
    [string]$ProjectKey,

    [Parameter(Mandatory)]
    [string]$IssueType,

    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter(Mandatory)]
    [string]$IssueSummary,

    [Parameter()]
    [string]$IssueKey,

    [Parameter()]
    [string]$Status,

    ## This is only a placeholder for AnyID and is not used
    [Parameter()]
    [securestring]$NewPassword
)

$ErrorActionPreference = 'Stop'

# Function to invoke JIRA API
function Invoke-JiraApi {
    [CmdletBinding()]
    param (
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Body
    )

    $apiUrl = "$SiteUrl/rest/api/2$Endpoint"
    $plainTextApiToken = (New-Object PSCredential "user", $ApiToken).GetNetworkCredential().Password
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $JiraUsername, $plainTextApiToken)))
    
    $headers = @{
        Authorization  = "Basic $base64AuthInfo"
        "Content-Type" = "application/json"
    }

    try {
        $params = @{
            Uri = $apiUrl
            Method = $Method
            Headers = $headers
            StatusCodeVariable = 'StatusCode'
        }
        if ($Body) { $params['Body'] = ($Body | ConvertTo-Json -Depth 10) }
        
        $response = Invoke-RestMethod @params

        [PSCustomObject]@{
            Response   = $response
            StatusCode = $StatusCode
        }
    } catch {
        throw "Error calling Jira API: $_"
    }
}

# Function to get project details
function Get-JiraProject {
    param ([string]$ProjectKey)
    
    $projectEndpoint = "/project/$ProjectKey"
    $projectResult = Invoke-JiraApi -Method 'GET' -Endpoint $projectEndpoint
    
    if (-not $projectResult.Response) {
        throw "Project with key '$ProjectKey' does not exist."
    }
    
    $projectResult.Response
}

# Function to get available issue types for a project
function Get-JiraProjectIssueTypes {
    param ([string]$ProjectKey)
    
    $issueTypesEndpoint = "/project/$ProjectKey/statuses"
    $issueTypesResult = Invoke-JiraApi -Method 'GET' -Endpoint $issueTypesEndpoint
    
    $issueTypesResult.Response
}

# Function to create or update JIRA issue
function Set-JiraIssue {
    param (
        [hashtable]$IssueData,
        [string]$IssueKey
    )

    if ($IssueKey) {
        $updateEndpoint = "/issue/$IssueKey"
        $updateResult = Invoke-JiraApi -Method 'PUT' -Endpoint $updateEndpoint -Body $IssueData
        if ($updateResult.StatusCode -ne 204) {
            throw "Failed to update JIRA ticket."
        }
    } else {
        $newIssue = Invoke-JiraApi -Method 'POST' -Endpoint '/issue' -Body $IssueData
        if (-not $newIssue.Response) {
            throw "Failed to create JIRA ticket."
        }
        $IssueKey = $newIssue.Response.key
    }
    
    $IssueKey
}

# Function to update issue status
function Set-JiraIssueStatus {
    param (
        [string]$IssueKey,
        [string]$Status
    )

    $transitionsEndpoint = "/issue/$IssueKey/transitions"
    $availableTransitions = Invoke-JiraApi -Method 'GET' -Endpoint $transitionsEndpoint

    $transitionId = $availableTransitions.Response.transitions | 
        Where-Object { $_.to.name -eq $Status } | 
        Select-Object -ExpandProperty id

    if (-not $transitionId) {
        throw "Unable to find a valid transition to status '$Status'"
    }

    $transitionBody = @{
        transition = @{ id = $transitionId }
    }

    $statusUpdateResult = Invoke-JiraApi -Method 'POST' -Endpoint $transitionsEndpoint -Body $transitionBody
    if ($statusUpdateResult.StatusCode -ne 204) {
        throw "Failed to update issue status."
    }
}

try {
    $ProjectKey = $ProjectKey.ToUpper()

    # Validate IssueType
    $validIssueTypes = @('Task', 'Bug', 'Story', 'Epic', 'Subtask', 'Incident', 'Service Request', 'Change', 'Problem')
    if ($IssueType -and $IssueType -notin $validIssueTypes) {
        throw "Invalid IssueType. Allowed values are: $($validIssueTypes -join ', ')"
    }

    # Validate Status if provided
    $validStatuses = @('To Do', 'In Progress', 'Done')
    if ($Status) {
        if ($Status -notin $validStatuses) {
            throw "Invalid Status. Allowed values are: $($validStatuses -join ', ')"
        }
        Set-JiraIssueStatus -IssueKey $updatedIssueKey -Status $Status
    }

    # Validate project and issue type
    $project = Get-JiraProject -ProjectKey $ProjectKey
    $availableIssueTypes = Get-JiraProjectIssueTypes -ProjectKey $ProjectKey
    $matchingIssueType = $availableIssueTypes | Where-Object { $_.name -eq $IssueType } | Select-Object -First 1

    if (-not $matchingIssueType) {
        throw "Issue type '$IssueType' is not available for this project."
    }

    # Prepare issue data
    $issueData = @{
        fields = @{
            project   = @{ key = $ProjectKey }
            summary   = $IssueSummary
            issuetype = @{ id = $matchingIssueType.id }
        }
    }

    if ($UserName) {
        $issueData.fields.description = "The user [$UserName]'s password has changed."
    }

    # Create or update issue
    $updatedIssueKey = Set-JiraIssue -IssueData $issueData -IssueKey $IssueKey    

    $true
} catch {
    $false
    Write-Error "Error creating or updating JIRA ticket: $_"
}
