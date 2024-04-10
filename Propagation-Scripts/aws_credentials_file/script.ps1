<#
.SYNOPSIS
This script updates AWS IAM credentials in a credentials file on a remote endpoint.

.DESCRIPTION
The script updates the AWS IAM access key ID and secret access key for a specified profile within an AWS credentials file. 
It supports updating credentials in a specific file or scanning multiple profiles across user profiles. 
The script connects to a remote endpoint using provided credentials and executes the update process remotely.

.PARAMETER Endpoint
Specifies the endpoint (computer name or IP address) where the AWS credentials file resides.

.PARAMETER EndpointUserName
Specifies the user name to connect to the endpoint. This user must have the necessary permissions to access and modify the AWS credentials file.

.PARAMETER EndpointPassword
Specifies the password for the EndpointUserName in a secure string format.

.PARAMETER OldIAMAccessKeyId
Specifies the old IAM access key ID that will be replaced in the AWS credentials file.

.PARAMETER NewIAMAccessKeyId
Specifies the new IAM access key ID to update in the AWS credentials file.

.PARAMETER NewPassword
Specifies the new IAM secret access key in a secure string format.

.PARAMETER ProfileName
(Optional) Specifies the profile name(s) to update in the AWS credentials file. If omitted, all profiles with the OldIAMAccessKeyId will be updated.

.PARAMETER CredentialsFilePath
(Optional) Specifies the path to the AWS credentials file to be updated. If omitted, the script will search for the credentials file in all user profiles.

.EXAMPLE
PS> .\script.ps1 -Endpoint "Server01" -EndpointUserName "admin" -EndpointPassword (ConvertTo-SecureString "password" -AsPlainText -Force) -OldIAMAccessKeyId "AKIAIOSFODNN7EXAMPLE" -NewIAMAccessKeyId "AKIAI44QH8DHBEXAMPLE" -NewPassword (ConvertTo-SecureString "newSecretAccessKey" -AsPlainText -Force)

This example updates the AWS IAM credentials in the default location on the remote server "Server01" for all profiles matching the old access key ID.

.EXAMPLE
PS> .\script.ps1 -Endpoint "Server01" -EndpointUserName "admin" -EndpointPassword (ConvertTo-SecureString "password" -AsPlainText -Force) -OldIAMAccessKeyId "AKIAIOSFODNN7EXAMPLE" -NewIAMAccessKeyId "AKIAI44QH8DHBEXAMPLE" -NewPassword (ConvertTo-SecureString "newSecretAccessKey" -AsPlainText -Force) -ProfileName "default" -CredentialsFilePath "C:\Users\Admin\.aws\credentials"

This example updates the AWS IAM credentials for the "default" profile in a specified credentials file on the remote server "Server01".
#>

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

# Outputs script parameters and the current user for logging purposes
Write-Output -InputObject “Running script with parameters: $($PSBoundParameters | Out-String) as [$(whoami)]”

#region Functions
# Creates a PSCredential object using provided username and password
function newCredential([string]$UserName, [securestring]$Password) {
    New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
}
#endregion

# Create credential object for remote connection
$credential = newCredential $EndpointUserName $EndpointPassword

# Script block to execute on the remote server
$scriptBlock = {

    # Set error preference to stop to halt on errors
    $ErrorActionPreference = 'Stop'

    #region functions
    # Decrypts a secure string password into a plain string
    function decryptPassword {
        param(
            [securestring]$Password
        )
        try {
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    # Finds AWS credential profiles either in a specified file or default locations
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

        # Handle custom or default credentials file path
        if ($PSBoundParameters.ContainsKey('CredentialsFilePath')) {
            $credentialFiles = Get-ChildItem -Path $CredentialsFilePath
        } else {
            $profilesDirectory = [Environment]::ExpandEnvironmentVariables((Get-ItemProperty -Path “HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList”).ProfilesDirectory)
            $credentialFiles = Get-ChildItem -Path $profilesDirectory -Recurse -Filter “credentials” -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Directory.Name -eq '.aws' }
        }

        # Process each found credentials file
        foreach ($credFile in $credentialFiles) {
            $content = Get-Content -Path $credFile.FullName -Raw
            $profiles = @()
            $currentProfile = $null

            # Parse credentials file content
            foreach ($line in $content -split “\r?\n”) {
                if ($line -match '^\[([^]]+)\]') {
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
            if ($null -ne $currentProfile) {
                $profiles += [pscustomobject]$currentProfile
            }

            # Filter profiles by name if specified
            $profiles.where({ !$ProfileName -or $_.name -in $ProfileName })
        }
    }
    
    # Updates AWS credentials file with new access and secret keys
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

            # Iterate over file lines to update the specific profile
            foreach ($line in $content) {
                if ($line -match '^\[' + [regex]::Escape($AwsProfile.name) + '\]') {
                    $insideProfile = $true
                    $updatedContent += $line
                } elseif ($line -match '^\[') {
                    $insideProfile = $false
                    $updatedContent += $line
                } elseif ($insideProfile) {
                    if ($line -match '^aws_access_key_id\s*=') {
                        $updatedContent += "aws_access_key_id = $NewAccessKeyID"
                    } elseif ($line -match '^aws_secret_access_key\s*=') {
                        $updatedContent += "aws_secret_access_key = $NewSecretAccessKey"
                    } else {
                        $updatedContent += $line
                    }
                } else {
                    $updatedContent += $line
                }
            }

            # Write the updated content back to the credentials file
            $updatedContent | Set-Content -Path $AwsProfile.CredentialsFilePath
            Write-Verbose “Updated profile $($AwsProfile.name) in the credentials file.”
        }
    }
    #endregion

    # Script block's main logic starts here...
    # Define parameters for the Find-AWSCredentialFileProfile function
    $findCredFileParams = @{}
    if ($args[3]) {
        $findCredFileParams.CredentialsFilePath = $args[3]
    }
    if ($args[4]) {
        $findCredFileParams.ProfileName = $args[4]
    }

    # Find profiles to update based on the old IAM Access Key ID
    $foundCredentialFileProfiles = Find-AWSCredentialFileProfile @findCredFileParams
    $oldIAMAccessKeyId = $args[0]
    $matchingCredentialFileProfiles = @($foundCredentialFileProfiles).where({ $_.aws_access_key_id -eq $oldIAMAccessKeyId })

    # Update the found profiles with the new IAM Access Key ID and Secret Access Key
    $matchingCredentialFileProfiles | Update-AWSCredentialsFileProfile -NewAccessKeyID $args[1] -NewSecretAccessKey (decryptPassword($args[2]))
}

# Prepare the profile and credentials file paths if provided
if ($PSBoundParameters.ContainsKey('ProfileName')) {
    $profileNames = $ProfileName -split ','
}
if ($PSBoundParameters.ContainsKey('CredentialsFilePath')) {
    $credentialsFilePaths = $CredentialsFilePath -split ','
}

# Execute the script block on the remote computer using Invoke-Command
try {
    $invParams = @{
        ComputerName = $Endpoint
        ScriptBlock  = $scriptBlock
        Credential   = $credential
        ArgumentList = $OldIAMAccessKeyId, $NewIAMAccessKeyId, $NewPassword, $credentialsFilePaths, $profileNames
    }
    Invoke-Command @invParams
} catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
    # Exception handling for connection issues
    throw "Script is unable to connect to the remote computer [$Endpoint]."
}