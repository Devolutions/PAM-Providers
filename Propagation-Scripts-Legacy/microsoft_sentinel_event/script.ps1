<#
.SYNOPSIS
    Sends a password change notification to Microsoft Sentinel.

.DESCRIPTION
    This script uses the HTTP Data Collector API to send a password change event to Microsoft Sentinel. It creates a log 
    entry in the specified Log Analytics workspace with an event of "password changed" and the provided username.

.PARAMETER WorkspaceId
    The ID of the Log Analytics workspace where the event will be sent.

.PARAMETER WorkspaceKey
    The primary or secondary key of the Log Analytics workspace.

.PARAMETER LogName
    The name of the custom log in Log Analytics. Defaults to "PasswordChangeNotification".

.PARAMETER UserName
    The username associated with the password change event.

.PARAMETER NewPassword
    The new password, provided as a SecureString. This parameter is not used in the current implementation.

.NOTES
    - Requires PowerShell 7.0 or later.
    - Prerequisites: 
      * Log Analytics workspace
      * Microsoft Sentinel workspace
      * Security Intelligence Pack: Security Insights
    - To get the Workspace ID:
      $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $workspaceName -Location $location
    - To get the Workspace Key:
      $workspaceKey = (Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $resourceGroupName -Name $workspaceName).PrimarySharedKey
    - The log type in Log Analytics will be "PasswordChangeNotification_CL".

.EXAMPLE
    PS> $workspaceId = "12345678-90ab-cdef-ghij-klmnopqrstuv"
    PS> $workspaceKey = ConvertTo-SecureString "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789==" -AsPlainText -Force
    PS> $userName = "johndoe"
    PS> .\Send-PasswordChangeNotification.ps1 -WorkspaceId $workspaceId -WorkspaceKey $workspaceKey -UserName $userName

    This example sends a password change notification for user "johndoe" to the specified Log Analytics workspace.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$WorkspaceId,

    [Parameter(Mandatory)]
    [securestring]$WorkspaceKey,

    [Parameter()]
    [string]$LogName = "PasswordChangeNotification",

    [Parameter(Mandatory)]
    [string]$UserName,

    [Parameter()]
    [securestring]$NewPassword
)

$ErrorActionPreference = 'Stop'

function decryptSecureString {
    param(
        [securestring]$SecureString
    )
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function New-Signature {
    param (
        [string]$WorkspaceId,
        [string]$WorkspaceKey,
        [string]$LogEntry
    )

    # Prepare the data to send
    $currentTime = [DateTime]::UtcNow.ToString("o")
    Write-Debug "Current time: $currentTime"

    $method = "POST"
    $contentType = "application/json"
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    Write-Debug "RFC1123 date: $rfc1123date"

    $contentLength = ([System.Text.Encoding]::UTF8.GetBytes($LogEntry)).Length
    Write-Debug "Content length: $contentLength"

    $xHeaders = "x-ms-date:$rfc1123date"
    $stringToHash = "$method`n$contentLength`n$contentType`n$xHeaders`n$resource"
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($WorkspaceKey)
    $hmacsha256 = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha256.Key = $keyBytes
    $calculatedHash = $hmacsha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    
    # Return a hashtable with all the necessary information
    @{
        Signature = "SharedKey ${WorkspaceId}:${encodedHash}"
        RFC1123Date = $rfc1123date
        Method = $method
        ContentType = $contentType
        Resource = $resource
        ContentLength = $contentLength
    }
}

function Send-LogToSentinel {
    param (
        [string]$WorkspaceId,
        [string]$LogName,
        [string]$signature,
        [string]$rfc1123date,
        [string]$resource,
        [string]$method,
        [string]$contentType,
        [string]$logEntry
    )

    $uri = "https://${WorkspaceId}.ods.opinsights.azure.com${resource}?api-version=2016-04-01"
    Write-Debug "URI: $uri"

    $headers = @{
        "Authorization"        = $signature
        "Log-Type"             = $LogName
        "x-ms-date"            = $rfc1123date
        "time-generated-field" = "TimeGenerated"
    }
    Write-Debug "Headers: $($headers | ConvertTo-Json -Compress)"

    $params = @{
        Uri                  = $uri
        Method               = $method
        ContentType          = $contentType
        Headers              = $headers
        Body                 = $logEntry
        UseBasicParsing      = $true
        StatusCodeVariable   = 'statusCode'
    }
    $response = Invoke-RestMethod @params
    Write-Debug "Status Code: $statusCode"
    write-debug "Response: $response"
    if ($statusCode -ne 200) {
        throw "Failed to send log to Sentinel. Status code: $statusCode"
    }
    $response
}

try {
    $logEntry = @{
        TimeGenerated = [DateTime]::UtcNow.ToString("o")
        AccountName   = $UserName
        Event         = "Password Changed"
    } | ConvertTo-Json
    Write-Debug "Log entry: $logEntry"

    $signatureInfo = New-Signature -WorkspaceId $WorkspaceId -WorkspaceKey (decryptSecureString $WorkspaceKey) -LogEntry $logEntry
    
    $response = Send-LogToSentinel -WorkspaceId $WorkspaceId -LogName $LogName `
        -signature $signatureInfo.Signature -rfc1123date $signatureInfo.RFC1123Date `
        -resource $signatureInfo.Resource -method $signatureInfo.Method `
        -contentType $signatureInfo.ContentType -logEntry $logEntry

    $response
} catch {
    Write-Error "An error occurred while sending the password change notification: $_"
    $false
}