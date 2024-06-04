[CmdletBinding()]
Param (
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$TenantID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$ApplicationID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$Password,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$KeyVaultName,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$Name,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$NewPassword
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
    # The Get-AzKeyVaultSecret does not support retrieve by ID
    $RetrievedSecret = $Vault | Get-AzKeyVaultSecret -Name $Name -ErrorAction 'Stop'
  } Catch {
    Write-Error ("Failed to Retrieve Secrets: {0}" -F $PSItem.Exception.ToString())
  }

  If ($RetrievedSecret) {
    Try {
      $Result = Set-AzKeyVaultSecret -Vault $Vault.VaultName -Name $RetrievedSecret.Name -SecretValue $NewPassword -ErrorAction 'Stop'
    } Catch {
      Write-Error "Failed to retrieve password: $($PSItem.Exception.ToString())"
    }

    If ($Result) {
      Return $True
    } Else {
      Write-Error "Failed to Update Secret"
    }
  } Else {
    Write-Error "Failed to find secrets by name"
  }
}