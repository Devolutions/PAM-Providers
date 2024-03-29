[CmdletBinding()]
Param (
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$TenantID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$ApplicationID,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$Password,
  [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$KeyVaultName
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

If ((Get-ExecutionPolicy) -NE 'RemoteSigned' -Or (Get-ExecutionPolicy) -NE 'Unrestricted') {
  Set-ExecutionPolicy 'RemoteSigned' -Scope 'Process'
}

$ModulesToImport = @{
  'Az.Accounts' = '2.10.3'
  'Az.KeyVault' = '4.9.0'
}

# If your minimum version is older, run Update-Module -Name 'Az'
$ModulesToImport.GetEnumerator() | ForEach-Object {
  Try {
    Import-Module -Name $PSItem.Key -MinimumVersion $PSItem.Value -ErrorAction 'Stop'
  } Catch {
    Write-Error ("Failed to Import Module: {0}" -F $Error[0].Exception.ToString())
    Exit
  }
}


$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationID, $Password

Try {
  $Account = Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Connect to Azure: {0}" -F $Error[0].Exception.ToString())
  Exit
}

Try {
  $Vault = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction 'Stop'
} Catch {
  Write-Error ("Failed to Retrieve Key Vault: {0}" -F $Error[0].Exception.ToString())
  Exit
}

If ($Vault) {
  Try {
    $Secrets = $Vault | Get-AzKeyVaultSecret
  } Catch {
    Write-Error ("Failed to Retrieve Secrets: {0}" -F $Error[0].Exception.ToString())
  }

  If ($Secrets) {
    $ParsedSecrets = $Secrets | ForEach-Object {
      Try {
        $Secret = $Vault | Get-AzKeyVaultSecret -Name $PSItem.Name -AsPlainText -ErrorAction 'Stop'
      } Catch {
        Write-Error ("Failed to Retrieve Secret: {0}" -F $Error[0].Exception.ToString())
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