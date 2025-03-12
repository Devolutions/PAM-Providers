<#
.SYNOPSIS
Sends a password change event to Splunk using the HTTP Event Collector (HEC).

.DESCRIPTION
This script sends a password change event to Splunk using the HTTP Event Collector (HEC). It connects to a Splunk server, 
prepares an event with the password change information, and sends it to Splunk. The script is designed to be used as a 
propagation script in the Devolutions PAM (Privileged Access Management) module.

.PARAMETER SplunkHost
The hostname or IP address of the Splunk server.

.PARAMETER HECToken
A secure string containing the HTTP Event Collector (HEC) token for authentication with Splunk.

.PARAMETER UserName
The username of the account for which the password was changed.

.PARAMETER NewPassword
A secure string containing the new password. This parameter is not used in the current implementation but is required for compatibility with the PAM module.

.PARAMETER Source
The source of the event as it will appear in Splunk. If not specified, it defaults to "DevolutionsPAM".

.PARAMETER Port
The port number for the Splunk HEC. If not specified, it defaults to 8088.

.PARAMETER Protocol
The protocol to use for the connection to Splunk. Valid values are "http" or "https". If not specified, it defaults to "https".

.EXAMPLE
$hecToken = ConvertTo-SecureString "YourHECTokenHere" -AsPlainText -Force
$newPassword = ConvertTo-SecureString "NewPassword123!" -AsPlainText -Force
.\Send-SplunkPasswordChangeEvent.ps1 -SplunkHost "splunk.example.com" -HECToken $hecToken -UserName "john.doe" -NewPassword $newPassword

This example sends a password change event for user "john.doe" to the Splunk server at "splunk.example.com" using the specified HEC token.

.NOTES
- Ensure that the HEC token has the necessary permissions to send events to Splunk.
- The script uses HTTPS by default and skips certificate validation. In a production environment, proper certificate validation should be implemented.
- This script is designed to be used with Devolutions PAM module and follows its propagation script requirements.
- The NewPassword parameter is not used in the current implementation but is required for compatibility with the PAM module.

.LINK
https://docs.devolutions.net/server/privileged-access-management/password-propagation/

.LINK
https://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory)]
    [string]$SplunkHost,

    [Parameter(Mandatory)]
    [securestring]$HECToken,

    [Parameter(Mandatory)]
    [string]$UserName,

    ## placeholder; not used
    [Parameter()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$Source,

    [Parameter()]
    [int]$Port,

    [Parameter()]
    [ValidateSet('',"http", "https")]
    [string]$Protocol
)

$ErrorActionPreference = 'Stop'

#region functions
function decryptSecureString ([securestring]$SecureString) {
    # Decrypts a secure string
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted secret from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Connect-Splunk {
    <#
    .SYNOPSIS
        Connects to a Splunk server using either user credentials or a HEC (HTTP Event Collector) token.

    .DESCRIPTION
        The Connect-Splunk function establishes a connection to a Splunk server specified by the ComputerName parameter. It supports two methods of 
        authentication: using user credentials or an HTTP Event Collector (HEC) token. Based on the provided parameter set, it configures the 
        appropriate port and authentication method.

    .PARAMETER ComputerName
        The name or IP address of the Splunk server to connect to. This parameter is mandatory.

    .PARAMETER Port
        The port number to connect to on the Splunk server. If not specified, the default port is 8089 for credential-based authentication 
        and 8088 for HEC token-based authentication.

    .PARAMETER Protocol
        The protocol used for the connection. The default value is "https".

    .PARAMETER Credential
        A PSCredential object that contains the username and password for authentication. This parameter is mandatory when using the 'Credential' 
        parameter set.

    .PARAMETER HECToken
        A secure string representing the HTTP Event Collector token for authentication. This parameter is mandatory when using the 'HECToken' 
        parameter set.

    .NOTES
        For more information on Splunk authentication, visit: https://docs.splunk.com/Documentation/Splunk/latest/Security/Aboutauthentication

    .EXAMPLE
        PS> Connect-Splunk -ComputerName "splunkserver" -Credential (Get-Credential)
        @{
            ComputerName = "splunkserver"
            Port         = 8089
            Protocol     = "https"
            AuthToken    = <SecureString>
            HECToken     = $null
        }

        Connects to the Splunk server 'splunkserver' using user credentials. The port is set to 8089 and protocol to 'https'. The authentication 
        token is returned as a secure string.

    .EXAMPLE
        PS> Connect-Splunk -ComputerName "splunkserver" -HECToken (ConvertTo-SecureString "your-hec-token" -AsPlainText -Force)
        @{
            ComputerName = "splunkserver"
            Port         = 8088
            Protocol     = "https"
            AuthToken    = $null
            HECToken     = <SecureString>
        }

        Connects to the Splunk server 'splunkserver' using an HEC token for authentication. The port is set to 8088 and protocol to 'https'. The 
        HEC token is returned as a secure string.
    #>

    [CmdletBinding(DefaultParameterSetName = 'HECToken')]
    Param(
        [Parameter(Mandatory)]
        [String]$ComputerName,
        
        [Parameter(Mandatory)]
        [int]$Port,
        
        [Parameter(Mandatory)]
        [String]$Protocol,
        
        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [pscredential]$Credential,

        [Parameter(Mandatory, ParameterSetName = 'HECToken')]
        [securestring]$HECToken
    )

    $outObj = @{
        ComputerName = $ComputerName
        Port         = $Port
        Protocol     = $Protocol
        AuthToken    = $null
        HECToken     = $null
    }

    if ($PSCmdlet.ParameterSetName -eq 'Credential') {
        $authParams = @{
            ComputerName = $ComputerName
            Port         = $Port
            Protocol     = $Protocol
            Credential   = $Credential
        }

        $authToken = Get-SplunkAuthToken @authParams
        $outObj.AuthToken = $authToken.AuthToken | ConvertTo-SecureString -AsPlainText -Force
    } else {
        $outObj.HECToken = $HECToken
    }

    $outObj
}

function Get-SplunkAuthToken {
    <#
    .SYNOPSIS
        Retrieves an authentication token from a Splunk server using provided credentials.

    .DESCRIPTION
        The Get-SplunkAuthToken function authenticates to a Splunk server using the specified username and password, and retrieves an authentication 
        token. This token can be used for subsequent authenticated requests to the Splunk server.

    .PARAMETER ComputerName
        The name or IP address of the Splunk server to connect to. This parameter is mandatory.

    .PARAMETER Port
        The port number to connect to on the Splunk server. The default value is 8089.

    .PARAMETER Protocol
        The protocol used for the connection, either "http" or "https". The default value is "https".

    .PARAMETER Credential
        A PSCredential object that contains the username and password for authentication. This parameter is mandatory.

    .NOTES
        For more information on Splunk authentication, visit: https://docs.splunk.com/Documentation/Splunk/latest/Security/Aboutauthentication

    .EXAMPLE
        PS> $cred = Get-Credential
        PS> Get-SplunkAuthToken -ComputerName "splunkserver" -Credential $cred
        @{
            ComputerName = "splunkserver"
            UserName     = "admin"
            AuthToken    = "your-session-key"
        }

        Retrieves an authentication token from the Splunk server 'splunkserver' using the provided credentials. The session key is returned in the 
        AuthToken field.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$ComputerName,
        
        [Parameter()]
        [int]$Port = 8089,
        
        [Parameter()]
        [String]$Protocol = "https",
        
        [Parameter(Mandatory)]
        [pscredential]$Credential
    )

    $uri = "${Protocol}://${ComputerName}:${Port}/services/auth/login"
    $body = @{
        username = $Credential.UserName
        password = $Credential.GetNetworkCredential().Password
    }

    $params = @{
        Uri             = $uri
        Method          = 'Post'
        Body            = $body
        ErrorAction     = 'Stop'
        UseBasicParsing = $true
    }
    if ($Protocol -eq 'https') {
        $params.SkipCertificateCheck = $true
    }
        
    $response = Invoke-RestMethod @params
        
    Write-Verbose "Response Content: $($response | Out-String)"
        
    # Parse the XML response
    $sessionKey = $response.response.sessionKey

    if (-not $sessionKey) {
        throw "Failed to retrieve session key from response"
    }

    [PSCustomObject]@{
        ComputerName = $ComputerName
        UserName     = $Credential.UserName
        AuthToken    = $sessionKey
    }
}

function Invoke-SplunkAPIRequest {
    <#
    .SYNOPSIS
        Sends a request to a specified Splunk API endpoint.

    .DESCRIPTION
        The Invoke-SplunkAPIRequest function sends an HTTP request to a specified Splunk API endpoint using the connection details and 
        authentication information provided in the Connection object. The function supports various HTTP methods and can include a body in 
        the request.

    .PARAMETER Connection
        A PSCustomObject containing the connection details, including ComputerName, Port, Protocol, AuthToken, and HECToken. This parameter 
        is mandatory.

    .PARAMETER Endpoint
        The specific API endpoint to which the request will be sent. This parameter is mandatory.

    .PARAMETER Method
        The HTTP method to use for the request, such as GET, POST, PUT, or DELETE. The default value is GET.

    .PARAMETER Body
        A hashtable representing the body of the request. This will be converted to JSON format and included in the request if provided.

    .NOTES
        For more information on Splunk's REST API, visit: https://docs.splunk.com/Documentation/Splunk/latest/RESTREF/RESTprolog

    .EXAMPLE
        PS> $connection = Connect-Splunk -ComputerName "splunkserver" -Credential (Get-Credential)
        PS> Invoke-SplunkAPIRequest -Connection $connection -Endpoint "services/search/jobs" -Method Post -Body @{ search = "search index=_internal | head 10" }
        {
            "sid": "random-search-id"
        }

        Sends a POST request to the 'services/search/jobs' endpoint on the Splunk server 'splunkserver' to create a new search job, using the provided 
        connection details and search query in the request body. The search ID (sid) is returned.

    .EXAMPLE
        PS> $connection = Connect-Splunk -ComputerName "splunkserver" -HECToken (ConvertTo-SecureString "your-hec-token" -AsPlainText -Force)
        PS> Invoke-SplunkAPIRequest -Connection $connection -Endpoint "services/collector/event" -Method Post -Body @{ event = "Hello Splunk!" }
        {
            "text": "Success",
            "code": 0
        }

        Sends a POST request to the 'services/collector/event' endpoint on the Splunk server 'splunkserver' to send a custom event, using the provided 
        connection details and event data in the request body. The response indicates success.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Connection,
        
        [Parameter(Mandatory)]
        [String]$Endpoint,
        
        [Parameter()]
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        
        [Parameter()]
        [Hashtable]$Body
    )

    $uri = "$($Connection.Protocol)://$($Connection.ComputerName):$($Connection.Port)/$Endpoint"

    $authString = 'Splunk '
    if ($Connection.HECToken) {
        $authString += (decryptSecureString $Connection.HECToken)
    } else {
        $authString += (decryptSecureString $Connection.AuthToken)
    }

    $headers = @{
        "Authorization" = $authString
        "Content-Type"  = "application/json"
    }

    $params = @{
        Uri                  = $uri
        Method               = $Method
        Headers              = $headers
        SkipCertificateCheck = $true
    }

    if ($Body) {
        $params.Body = $Body | ConvertTo-Json
    }

    Invoke-RestMethod @params
}

function Wait-SplunkAcknowledgement {
    <#
.SYNOPSIS
    Waits for a Splunk event to be acknowledged.

.DESCRIPTION
    The Wait-SplunkAcknowledgement function waits for a specified Splunk event to be acknowledged. It repeatedly checks the acknowledgement 
    status at defined intervals until the event is acknowledged or a timeout is reached.

.PARAMETER Connection
    A PSCustomObject containing the connection details, including ComputerName, Port, Protocol, AuthToken, and HECToken. This parameter is 
    mandatory.

.PARAMETER AckId
    The acknowledgement ID of the event to wait for. This parameter is mandatory.

.PARAMETER Channel
    The channel associated with the event acknowledgement. This parameter is mandatory.

.PARAMETER TimeoutSeconds
    The maximum number of seconds to wait for the event to be acknowledged. The default value is 60 seconds.

.PARAMETER RetryIntervalSeconds
    The number of seconds to wait between retries when checking for acknowledgement. The default value is 5 seconds.

.NOTES
    For more information on Splunk acknowledgements, visit: https://docs.splunk.com/Documentation/Splunk/latest/RESTREF/RESTendpoints

.EXAMPLE
    PS> $connection = Connect-Splunk -ComputerName "splunkserver" -Credential (Get-Credential)
    PS> Wait-SplunkAcknowledgement -Connection $connection -AckId "12345" -Channel "main"
    True

    Waits for the event with AckId '12345' to be acknowledged on the 'main' channel using the provided connection details. If the event is 
    acknowledged within the timeout period, it returns True.

.EXAMPLE
    PS> $connection = Connect-Splunk -ComputerName "splunkserver" -HECToken (ConvertTo-SecureString "your-hec-token" -AsPlainText -Force)
    PS> Wait-SplunkAcknowledgement -Connection $connection -AckId "67890" -Channel "hec" -TimeoutSeconds 120 -RetryIntervalSeconds 10
    False

    Waits for the event with AckId '67890' to be acknowledged on the 'hec' channel using the provided connection details. If the event is not 
    acknowledged within 120 seconds, it returns False.
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$Connection,

        [Parameter(Mandatory)]
        [string]$AckId,

        [Parameter(Mandatory)]
        [string]$Channel,

        [Parameter()]
        [int]$TimeoutSeconds = 60,

        [Parameter()]
        [int]$RetryIntervalSeconds = 5
    )

    $startTime = Get-Date
    $acknowledged = $false

    Write-Verbose "Waiting for acknowledgement of event with AckId: $AckId"

    while (-not $acknowledged -and ((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        $getSplunkAckParams = @{
            Connection = $Connection
            AckId      = $AckId
            Channel    = $Channel
        }

        try {
            $acknowledged = Get-SplunkAcknowledgement @getSplunkAckParams
            if ($acknowledged) {
                Write-Verbose "Event with AckId $AckId has been acknowledged."
                $true
            }
        } catch {
            Write-Warning "Error checking acknowledgement: $_"
        }

        Write-Verbose "Event not yet acknowledged. Waiting $RetryIntervalSeconds seconds before retrying..."
        Start-Sleep -Seconds $RetryIntervalSeconds
    }

    if (-not $acknowledged) {
        Write-Warning "Timeout reached. Event with AckId $AckId was not acknowledged within $TimeoutSeconds seconds."
        $false
    }
}

function Get-SplunkAcknowledgement {
    <#
    .SYNOPSIS
        Checks if a Splunk event with a specified acknowledgement ID has been indexed.

    .DESCRIPTION
        The Get-SplunkAcknowledgement function checks whether a Splunk event with the specified acknowledgement ID has been indexed on a 
        given channel. It uses the connection details provided in the Connection object to send a request to the Splunk API.

    .PARAMETER Connection
        A PSCustomObject containing the connection details, including ComputerName, Port, Protocol, AuthToken, and HECToken. This parameter 
        is mandatory.

    .PARAMETER AckId
        The acknowledgement ID of the event to check. This parameter is mandatory.

    .PARAMETER Channel
        The channel associated with the event acknowledgement. This parameter is mandatory.

    .NOTES
        For more information on Splunk acknowledgements, visit: https://docs.splunk.com/Documentation/Splunk/latest/RESTREF/RESTendpoints

    .EXAMPLE
        PS> $connection = Connect-Splunk -ComputerName "splunkserver" -Credential (Get-Credential)
        PS> Get-SplunkAcknowledgement -Connection $connection -AckId "12345" -Channel "main"
        True

        Checks if the event with AckId '12345' has been indexed on the 'main' channel using the provided connection details. If the event has 
        been indexed, it returns True.

    .EXAMPLE
        PS> $connection = Connect-Splunk -ComputerName "splunkserver" -HECToken (ConvertTo-SecureString "your-hec-token" -AsPlainText -Force)
        PS> Get-SplunkAcknowledgement -Connection $connection -AckId "67890" -Channel "hec"
        False

        Checks if the event with AckId '67890' has been indexed on the 'hec' channel using the provided connection details. If the event has 
        not been indexed, it returns False.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Connection,
        
        [Parameter(Mandatory)]
        [String]$AckId,

        [Parameter(Mandatory)]
        [String]$Channel
    )

    $invokeParams = @{
        Connection = $Connection
        Endpoint   = "services/collector/ack?channel=$Channel"
        Method     = "GET"
        Body       = @{acks = @($AckId) }
    }
    $response = Invoke-SplunkAPIRequest @invokeParams
    
    if ($response.acks.$AckId -eq "true") {
        Write-Verbose "Event with ackId $AckId has been successfully indexed."
        $true
    } else {
        Write-Verbose "Event with ackId $AckId has not been indexed yet."
        $false
    }
}

function Send-SplunkEvent {
    <#
    .SYNOPSIS
    Sends an event to Splunk using the HTTP Event Collector (HEC).

    .DESCRIPTION
    This function sends an event to Splunk using the HTTP Event Collector (HEC). It requires a connection object obtained from Connect-Splunk and a hashtable containing the event data.

    .PARAMETER Connection
    A PSCustomObject containing the Splunk connection details, typically obtained from the Connect-Splunk function.

    .PARAMETER EventData
    A hashtable containing the event data to be sent to Splunk. This should include at minimum a 'message' key, and can optionally include 'timestamp' and 'source' keys.

    .EXAMPLE
    $hecConnection = Connect-Splunk -ComputerName 'splunk.example.com' -HECToken 'xxxxxxxxx'
    $eventData = @{
        message   = 'User login successful'
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        source    = 'DevolutionsPAM'
    }
    Send-SplunkEvent -Connection $hecConnection -EventData $eventData 

    This example connects to Splunk using HEC, creates an event with a message, timestamp, and source, and sends it to Splunk.

    .EXAMPLE
    $hecToken = 'ecc94209-e037-43d5-aac9-396a289eee1e'
    $hecConnection = Connect-Splunk -ComputerName 'localhost' -HECToken ($hecToken | ConvertTo-SecureString -AsPlainText -Force)
    $eventData = @{
        event = "hello world"
    }
    Send-SplunkEvent -Connection $hecConnection -EventData $eventData

    This example demonstrates sending a simple "hello world" event to a local Splunk instance using a specific HEC token.

    .NOTES
    - Ensure that the HEC token has the necessary permissions to send events.
    - The timestamp should be in Unix epoch time (seconds since 1970-01-01 00:00:00 UTC).
    - If 'timestamp' is not provided in the EventData, Splunk will use the current time when it receives the event.
    - The 'source' field is optional but can be useful for filtering and searching events in Splunk.
    - To create an HTTP event collector, refer to: https://docs.splunk.com/Documentation/Splunk/9.2.2/Data/UsetheHTTPEventCollector
    - The default HEC port is 8088, while the management port is typically 8089.
    - Always use HTTPS and skip certificate checks in test environments only.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Connection,

        [Parameter(Mandatory)]
        [hashtable]$EventData
    )

    # Prepare the event data
    $eventData = @{                                                      
        event = $EventData
    }

    $invokeParams = @{
        Connection = $Connection
        Endpoint   = "services/collector/event"
        Method     = "POST"
        Body       = $eventData
    }

    Invoke-SplunkAPIRequest @invokeParams
}
#endregion

try {

    if (-not $Source) {
        $Source = "DevolutionsPAM"
    }

    if (-not $Protocol) {
        $Protocol = "https"
    }

    if (-not $Port -or $Port -eq 0) {
        $Port = 8088
    }

    # Connect to Splunk
    $splunkConnection = Connect-Splunk -ComputerName $SplunkHost -HECToken $HECToken -Port $Port -Protocol $Protocol

    # Prepare the event data
    $eventData = @{
        message   = "Password changed for user: $UserName"
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        source    = $Source
        user      = $UserName
        action    = "password_change"
    }

    # Send the event to Splunk
    $result = Send-SplunkEvent -Connection $splunkConnection -EventData $eventData

    if ($result.text -eq "Success") {
        Write-Output "Successfully sent password change event to Splunk for user: $UserName"
        $true
    } else {
        throw "Failed to send password change event to Splunk. Error: $($result.text)"
    }
} catch {
    Write-Error "An error occurred while sending the Splunk event: $_"
    $false
}