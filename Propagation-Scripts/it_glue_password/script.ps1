[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$EndpointApiKey,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PasswordName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$EndpointUri
)

#region Functions
function decryptPassword ([securestring]$Password) {
    # Decrypts a secure string password
    try {
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        ## Clear the decrypted password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function newQueryString([Hashtable]$QueryParams) {
    # Generates a URL-encoded query string from a hashtable of parameters
    # Load the System.Web assembly to access HttpUtility class
    Add-Type -AssemblyName System.Web

    # Initialize an empty query string collection
    $query = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)

    # Iterate over each key-value pair in the provided Hashtable of query parameters
    $QueryParams.GetEnumerator() | ForEach-Object {
        # Add each key-value pair to the query string collection
        $query.Add($_.Key, [System.Net.WebUtility]::UrlEncode($_.Value))
    }

    # Return the completed query string
    $query.ToString()
}

function invokeITGlueApiCall {
    # Invokes an API call to IT Glue
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceURI,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable]$ApiParameter,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [hashtable]$RequestBody
    )

    # Construct the full API URI by appending the resource URI to the base URI
    $apiUri = "$script:EndpointUri/$ResourceURI"

    # Setup the headers for the API call, including the API key
    $headers = @{
        'x-api-key' = (decryptPassword $script:EndpointApiKey) # Decrypt the API key for use in the header
    }

    # Initialize parameters for Invoke-RestMethod
    $irmParams = @{
        Uri                = $apiUri
        Method             = $Method # HTTP method (GET, POST, etc.)
        Headers            = $headers # Headers including the API key
        StatusCodeVariable = 'respStatus' # Capture the status code of the API response
        SkipHttpErrorCheck = $true
    }

    # If the method is not GET, specify the content type explicitly
    if ($Method -ne 'GET') {
        $irmParams.ContentType = 'application/vnd.api+json'
    }
    
    # If a request body is provided, convert it to JSON and add it to the parameters
    if ($PSBoundParameters.ContainsKey('RequestBody')) {
        $irmParams.Body = ($RequestBody | ConvertTo-Json)
    }
    
    # Add query string to the URI if ApiParameter is provided and AllResults is not present
    if ($PSBoundParameters.ContainsKey('ApiParameter')) {
        $queryString = newQueryString -Uri $apiUri -QueryParams $ApiParameter
        $irmParams.Uri = '{0}?{1}' -f $apiUri, $queryString
    }

    # Make the API call
    $response = Invoke-RestMethod @irmParams
    # If the response status code is not 200, throw the response as an error
    if ($respStatus -ne 200) {
        if ($response.errors) {
            throw $response.errors.detail
        } else {
            throw $response
        }
    }
    $response
}

function getITGluePassword($PasswordName) {
    # Retrieves a password from IT Glue by name
    $resourceUri = "passwords"
    $result = invokeITGlueApiCall -ResourceURI $resourceUri -ApiParameter @{ 'filter[name]' = $PasswordName }
    $result.data
}

function setITGluePassword($PasswordId, $Password) {
    # Updates a password in IT Glue by ID
    $resourceUri = "passwords/$PasswordId"

    $data = @{
        'data' = @{
            'type'       = 'passwords'
            'attributes' = @{
                'password' = (decryptPassword $Password)
            }
        }
    }
    $null = invokeITGlueApiCall -Method PATCH -ResourceURI $resourceUri -RequestBody $data -ApiParameter @{'show_password' = 'true' }
}
#endregion

## This is useful to see what parameters DVLS passed to the script
Write-Output -InputObject "Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]..."

# Set the preference to stop the script on any errors encountered
$ErrorActionPreference = 'Stop'

# If EndpointUri is not provided, use the default IT Glue API endpoint
if (!$EndPointUri) {
    $EndpointUri = 'https://api.itglue.com'
}

# Store the API key and endpoint URI in script-scoped variables for use in functions
$script:EndpointApiKey = $EndpointApiKey
$script:EndpointUri = $EndpointUri

try {
    # Retrieve the password from IT Glue by name
    $pw = getITGluePassword -PasswordName $PasswordName
    Write-Output -InputObject "Resetting password for password [$($PasswordName)] (ID: [$($pw.id)])..."
    
    # Update the password in IT Glue
    setITGluePassword -PasswordId $pw.id -Password $NewPassword
    Write-Output -InputObject 'Successfully reset password.'
    $true
} catch {
    # If the password is not found, throw a specific error message
    if ($_.Exception.Message -eq 'Record not found') {
        throw "The requested password [$($PasswordName)] was not found."
    }
    # Otherwise, re-throw the caught exception
    throw $_
}