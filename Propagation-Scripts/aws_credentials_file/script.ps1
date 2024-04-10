[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Endpoint,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$EndpointUserName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$EndpointPassword,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OldIAMAccessKeyId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$NewIAMAccessKeyId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [securestring]$NewPassword,

    [Parameter()]
    [string]$ProfileName,

    [Parameter()]
    [string]$CredentialsFilePath
)

# Output the script parameters and the current user running the script
Write-Output -InputObject “Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]”

#region Functions
# Function to create a new PSCredential object
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create a new PSCredential object using the provided EndpointUserName and EndpointPassword
$credential = newCredential $EndpointUserName $EndpointPassword

# Define a script block to be executed remotely on the Windows server
$scriptBlock = {

    $ErrorActionPreference = 'Stop'

    #region functions
    function decryptPassword {
        param(
            [securestring]$Password
        )
        try {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            ## Clear the decrypted password from memory
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    function Find-AWSCredentialFileProfile {
        [CmdletBinding()]
        param (
            [Parameter()]
            [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
            [string[]]$CredentialsFilePath,

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string[]]$ProfileName
        )

        if ($PSBoundParameters.ContainsKey('CredentialsFilePath')) {
            $credentialFiles = Get-ChildItem -Path $CredentialsFilePath
        } else {
            ## Look for credentials file across all user profiles
            $profilesDirectory = (Get-ItemProperty -Path “HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList”).ProfilesDirectory
            $profilesDirectory = [Environment]::ExpandEnvironmentVariables($profilesDirectory)

            $credentialFiles = Get-ChildItem -Path $profilesDirectory -Recurse -Filter “credentials” -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq '.aws' }
        }

        foreach ($credFile in $credentialFiles) {
    
            $content = Get-Content -Path $credFile.FullName -Raw
            $profiles = @() # Initialize an array to hold all profiles
            $currentProfile = $null

            foreach ($line in $content -split “\r?\n”) {
                if ($line -match '^\[([^]]+)\]') {
                    # Before resetting $currentProfile, add it to $profiles if it's not null
                    if ($null -ne $currentProfile) {
                        $profiles += [pscustomobject]$currentProfile
                    }
                    $currentProfile = [ordered]@{
                        Name                = $matches[1] -replace '^profile\s+', ''
                        CredentialsFilePath = $credFile.FullName
                    }
                } elseif ($line -match '^(aws_access_key_id|aws_secret_access_key|aws_session_token)\s*=\s*(.*)') {
                    if ($null -ne $currentProfile) {
                        $currentProfile[$matches[1]] = $matches[2]
                    }
                }
            }
            # Add the last profile after exiting the loop
            if ($null -ne $currentProfile) {
                $profiles += [pscustomobject]$currentProfile
            }

            $profiles.where({ !$ProfileName -or $_.name -in $ProfileName })
        }
    }
    
    function Update-AWSCredentialsFileProfile {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory, ValueFromPipeline)]
            [PSCustomObject]$AwsProfile,
            [Parameter(Mandatory)]
            [string]$NewAccessKeyID,
            [Parameter(Mandatory)]
            [string]$NewSecretAccessKey
        )
    
        Process {
            $content = Get-Content -Path $AwsProfile.CredentialsFilePath
            $updatedContent = @()
    
            $insideProfile = $false
            foreach ($line in $content) {
                if ($line -match '^\[' + [regex]::Escape($AwsProfile.name) + '\]') {
                    $insideProfile = $true
                    $updatedContent += $line
                } elseif ($line -match '^\[') {
                    $insideProfile = $false
                    $updatedContent += $line
                } elseif ($insideProfile) {
                    if ($line -match '^aws_access_key_id\s*=') {
                        $updatedContent += “aws_access_key_id = $NewAccessKeyID”
                    } elseif ($line -match '^aws_secret_access_key\s*=') {
                        $updatedContent += “aws_secret_access_key = $NewSecretAccessKey”
                    } else {
                        $updatedContent += $line
                    }
                } else {
                    $updatedContent += $line
                }
            }
            $updatedContent | Set-Content -Path $AwsProfile.CredentialsFilePath
            Write-Verbose “Updated profile $($AwsProfile.name) in the credentials file.”
        }
    }
    #endregion

    $findCredFileParams = @{}
    if ($args[3]) {
        $findCredFileParams.CredentialsFilePath = $args[3]
    }
    if ($args[4]) {
        $findCredFileParams.ProfileName = $args[4]
    }

    $foundCredentialFileProfiles = Find-AWSCredentialFileProfile @findCredFileParams
 
    ## Must assign this arg it's own var because it's being used inside of the where filter where $args is a thing
    $oldIAMAccessKeyId = $args[0]

    $matchingCredentialFileProfiles = @($foundCredentialFileProfiles).where({ $_.aws_access_key_id -eq $oldIAMAccessKeyId })

    $matchingCredentialFileProfiles | Update-AWSCredentialsFileProfile -NewAccessKeyID $args[1] -NewSecretAccessKey (decryptPassword($args[2]))
}

if ($PSBoundParameters.ContainsKey('ProfileName')) {
    $profileNames = $ProfileName -split ','
}
if ($PSBoundParameters.ContainsKey('CredentialsFilePath')) {
    $credentialsFilePaths = $CredentialsFilePath -split ','
}

try {
    $invParams = @{
        ComputerName = $Endpoint
        ScriptBlock  = $scriptBlock
        Credential   = $credential
        ArgumentList = $OldIAMAccessKeyId, $NewIAMAccessKeyId, $NewPassword, $credentialsFilePaths, $profileNames
    }
    Invoke-Command @invParams
} catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
    throw "Script is unable to connect to the remote computer [$Endpoint]."
}