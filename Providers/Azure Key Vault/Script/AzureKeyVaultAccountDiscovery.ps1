[CmdletBinding()]
Param (
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$TenantID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$ApplicationID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$Password,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$KeyVaultName
)

If (($PSVersionTable.PSVersion -LT [System.Version]'7.4.0') -Or $PSVersionTable.PSEdition -NE 'Core') {
	Write-Error "PowerShell version must be 7.4.0 or greater."
	Exit
}

# Ensure we are using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

If ((Get-ExecutionPolicy) -NE 'RemoteSigned' -Or (Get-ExecutionPolicy) -NE 'Unrestricted') {
	Try {
		Set-ExecutionPolicy 'RemoteSigned' -Scope 'Process' -ErrorAction 'Stop'
	} Catch {
		Write-Error ("Failed to Set Execution Policy: {0}" -F $PSItem.Exception.ToString())
		Exit
	}
}

# If you don't have the required Az modules installed, run the following:
# Install-Module -Name 'Az.Accounts' -Scope 'AllUsers' -RequiredVersion '2.16.0'
# Install-Module -Name 'Az.KeyVault' -Scope 'AllUsers' -RequiredVersion '5.2.1'
$ModulesToImport = @{
	'Az.Accounts' = @{
		'Required' = '2.16.0'
	}
	'Az.KeyVault' = @{
		'Required' = '5.2.1'
	}
}

$ModulesToImport.GetEnumerator() | ForEach-Object {
	Try {
		Import-Module -Name $PSItem.Key -RequiredVersion $PSItem.Value.Required -ErrorAction 'Stop'
	} Catch {
		Write-Error ("Failed to Import Module: {0}" -F $PSItem.Exception.ToString())
		Exit
	}
}

$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationID, $Password

Try {
	$Account = Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential -ErrorAction 'Stop'
} Catch {
	Write-Error ("Failed to Connect to Azure: {0}" -F $PSItem.Exception.ToString())
	Exit
}

Try {
	$Vault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction 'Stop'
} Catch {
	Write-Error ("Failed to Retrieve Key Vault: {0}" -F $PSItem.Exception.ToString())
	Exit
}

If ($Vault) {
	Try {
		$Secrets = $Vault | Get-AzKeyVaultSecret
	} Catch {
		Write-Error ("Failed to Retrieve Secrets: {0}" -F $PSItem.Exception.ToString())
	}

	If ($Secrets) {
		$ParsedSecrets = $Secrets | ForEach-Object {
			Try {
				$Secret = $Vault | Get-AzKeyVaultSecret -Name $PSItem.Name -AsPlainText -ErrorAction 'Stop'
			} Catch {
				Write-Error ("Failed to Retrieve Secret: {0}" -F $PSItem.Exception.ToString())
			}

			If ($Secret) {
				[PSCustomObject]@{
					'ID'     = $PSItem.Id
					'Name'   = $PSItem.Name
					'Secret' = $Secret
				}
			}
		}

		Return $ParsedSecrets
	} Else {
		Write-Error "No Secrets Found"
	}
} Else {
	Write-Error "Key Vault not Found"
}