[CmdletBinding()]
Param (
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$Hosts,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$LoginUsername,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[SecureString]$LoginPassword,
	[Parameter(Mandatory = $False)]
	[Boolean]$ExcludeDisabledAccountsInDiscovery,
	[Parameter(Mandatory = $False)]
	[String]$HostsLDAPSearchFilter,
	[Switch]$DebugOutput
)

[System.Management.Automation.ScriptBlock]$RemoteHostScript = {
	Param ($Hostname,
		$ExcludeDisabled)
	
	Function Get-LocalUserADSI
	{
		
		Begin
		{
			
			#region  Helper Functions
			
			Function ConvertTo-SID
			{
				
				Param ([byte[]]$BinarySID)
				
				(New-Object  System.Security.Principal.SecurityIdentifier($BinarySID, 0)).Value
				
			}
			
			Function Convert-UserFlag
			{
				
				Param ($UserFlag)
				
				$List = New-Object  System.Collections.ArrayList
				
				Switch ($UserFlag)
				{
					
					($UserFlag -BOR 0x0001) { [void]$List.Add('SCRIPT') }
					
					($UserFlag -BOR 0x0002) { [void]$List.Add('ACCOUNTDISABLE') }
					
					($UserFlag -BOR 0x0008) { [void]$List.Add('HOMEDIR_REQUIRED') }
					
					($UserFlag -BOR 0x0010) { [void]$List.Add('LOCKOUT') }
					
					($UserFlag -BOR 0x0020) { [void]$List.Add('PASSWD_NOTREQD') }
					
					($UserFlag -BOR 0x0040) { [void]$List.Add('PASSWD_CANT_CHANGE') }
					
					($UserFlag -BOR 0x0080) { [void]$List.Add('ENCRYPTED_TEXT_PWD_ALLOWED') }
					
					($UserFlag -BOR 0x0100) { [void]$List.Add('TEMP_DUPLICATE_ACCOUNT') }
					
					($UserFlag -BOR 0x0200) { [void]$List.Add('NORMAL_ACCOUNT') }
					
					($UserFlag -BOR 0x0800) { [void]$List.Add('INTERDOMAIN_TRUST_ACCOUNT') }
					
					($UserFlag -BOR 0x1000) { [void]$List.Add('WORKSTATION_TRUST_ACCOUNT') }
					
					($UserFlag -BOR 0x2000) { [void]$List.Add('SERVER_TRUST_ACCOUNT') }
					
					($UserFlag -BOR 0x10000) { [void]$List.Add('DONT_EXPIRE_PASSWORD') }
					
					($UserFlag -BOR 0x20000) { [void]$List.Add('MNS_LOGON_ACCOUNT') }
					
					($UserFlag -BOR 0x40000) { [void]$List.Add('SMARTCARD_REQUIRED') }
					
					($UserFlag -BOR 0x80000) { [void]$List.Add('TRUSTED_FOR_DELEGATION') }
					
					($UserFlag -BOR 0x100000) { [void]$List.Add('NOT_DELEGATED') }
					
					($UserFlag -BOR 0x200000) { [void]$List.Add('USE_DES_KEY_ONLY') }
					
					($UserFlag -BOR 0x400000) { [void]$List.Add('DONT_REQ_PREAUTH') }
					
					($UserFlag -BOR 0x800000) { [void]$List.Add('PASSWORD_EXPIRED') }
					
					($UserFlag -BOR 0x1000000) { [void]$List.Add('TRUSTED_TO_AUTH_FOR_DELEGATION') }
					
					($UserFlag -BOR 0x04000000) { [void]$List.Add('PARTIAL_SECRETS_ACCOUNT') }
					
				}
				
				$List -join ', '
				
			}
			
			#endregion  Helper Functions
			
		}
		
		Process
		{
			$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
			
			$adsi.Children | where { $_.SchemaClassName -eq 'user' } | ForEach {
				
				[pscustomobject]@{
					
					Name = $_.Name[0]
					Description = $_.Description[0]
					SID	     = ConvertTo-SID -BinarySID $_.ObjectSID[0]
					UserFlags = Convert-UserFlag -UserFlag $_.UserFlags[0]
					#PasswordAge = [math]::Round($_.PasswordAge[0]/86400)
					#LastLogin = If ($_.LastLogin[0] -is [datetime]) { $_.LastLogin[0] }Else{ 'Never logged  on' }
					#MinPasswordLength = $_.MinPasswordLength[0]
					#MinPasswordAge = [math]::Round($_.MinPasswordAge[0]/86400)
					#MaxPasswordAge = [math]::Round($_.MaxPasswordAge[0]/86400)
					#BadPasswordAttempts = $_.BadPasswordAttempts[0]
					#MaxBadPasswords = $_.MaxBadPasswordsAllowed[0]
					
				}
			}
		}
	}
	
	Try
	{
		
		If ($ExcludeDisabled)
		{
			$LocalAccounts = Get-LocalUserADSI | Where-Object { $_.UserFlags -notmatch 'ACCOUNTDISABLE' } -ErrorAction 'Stop'
		}
		Else
		{
			$LocalAccounts = Get-LocalUserADSI -ErrorAction 'Stop'
		}
		
		$Accounts = $LocalAccounts | ForEach-Object {
			[PSCustomObject]@{
				'Username' = $_.Name
				'Password' = "password"
				'HostName' = $Hostname
				'Hostname/SID' = $Hostname + "/" + $_.SId
				'SID'	   = $_.SId
				'Description' = $_.Description
			}
		}
		Write-Output $Accounts
	}
	Catch
	{
		Write-Error "LocalAccount failed to be retrieved on host $Hostname"
	}
	
}

function Get-WinRMNetworkParameters
{
	param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[String]$HostName)
	
	Import-Module NetTCPIP
	switch ($HostName)
	{
		({ (Resolve-DnsName -Name $_ -ErrorAction SilentlyContinue).IPAddress })
		{
			$SessionParameters = @{
				ComputerName = $Hostname
			}
			
			switch ($_)
			{
				({
						#check if host supports SSL Port
						[System.Net.Sockets.TcpClient]::new().ConnectAsync($_, 5986).Wait(100)
					})
				{
					$SessionParameters.Add("Port", 5986)
					$SessionParameters.Add("UseSSL", $True)
					Try
					{
						$result = Test-WSMan @SessionParameters
					}
					Catch
					{
						Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message $Error[0].Exception.ToString()
						#Write-Error $Error[0].Exception.ToString()
						return $null
					}
					return $SessionParameters
				}
				
				({
						#check if host supports non SSL Port
						[System.Net.Sockets.TcpClient]::new().ConnectAsync($_, 5985).Wait(100)
					})
				{
					$SessionParameters.Add("Port", 5985)
					Try
					{
						$result = Test-WSMan @SessionParameters
					}
					Catch
					{
						Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message $Error[0].Exception.ToString()
						#Write-Error $Error[0].Exception.ToString()
						return $null
					}
					return $SessionParameters
				}
				
				default
				{
					Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message "No connectivity on TCP ports 5985 or 5986 to $Hostname"
					#Write-Information "No connectivity on TCP ports 5985 or 5986 to $Hostname"
					return $null
				}
			}
		}
	}
}

function Get-WinRMSession
{
	param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		$WinRMNetworkParameters,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSCredential]$Credential
	)
	
	$WinRMNetworkParameters.Add("ErrorAction", "Stop")
	Try
	{
		$RemoteSession = New-PSSession @WinRMNetworkParameters
	}
	Catch
	{
		$WinRMNetworkParameters.Add("Credential", $Credential)
		Try
		{
			$RemoteSession = New-PSSession @WinRMNetworkParameters
		}
		Catch
		{
			$DNSsuffix = $hostname.SubString($hostname.IndexOf(".") + 1)
			$NewUsername = $Credential.UserName + "@" + $DNSsuffix
			$NewCredential = New-Object System.Management.Automation.PSCredential @($NewUsername, $Credential.Password)
			$WinRMNetworkParameters.Credential = $NewCredential
			Try
			{
				$RemoteSession = New-PSSession @WinRMNetworkParameters
			}
			Catch
			{
				Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message $Error[0].Exception.ToString()
				#Write-Error $Error[0].Exception.ToString()
			}
		}
	}
	If ($RemoteSession.State -eq 'Opened')
	{
		Write-EventLog -LogName Devolutions -EntryType Information -Source "DVLS" -EventId 1 -Message $("Powershell remoting session to " +$WinRMNetworkParameters.ComputerName + "created successfully")
		return $RemoteSession
	}
}

$Credential = New-Object System.Management.Automation.PSCredential @($LoginUsername, $LoginPassword)
$HostsArray = $Hosts -split "[ ,;]"

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Import-Module NetTCPIP

#If a single host is specified and that host is also listening on port 636 it is likely a domain controller, in which case enumerating local accounts would be redundant
#So instead enumerate active domain computers for the list of hosts to query for local accounts
If (($HostsArray.Count -eq 1) -and ([System.Net.Sockets.TcpClient]::new().ConnectAsync($HostsArray[0], 636).Wait(100)))
{
	$DomainFQDN = $HostsArray[0]
	$Credential = New-Object System.Management.Automation.PSCredential @("$LoginUsername@$DomainFQDN", $LoginPassword)
	
	Try
	{
		$ADSI = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DomainFQDN`:636", $Credential.UserName, $Credential.GetNetworkCredential().Password) -ErrorAction Stop
		[void]$ADSI.ToString()
	}
	Catch
	{
		Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message $Error[0].Exception.ToString()
		Write-Error $error[0].Exception.ToString()
	}
	
	If ($ADSI.distinguishedName -ne "")
	{
		$Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher($ADSI)
		$Searcher.Filter = "(&(objectclass=computer)" #Find only computer objects
		$Searcher.Filter += "(!useraccountcontrol:1.2.840.113556.1.4.804:=2)" #Exclude disable accounts
		$Searcher.Filter += "(!userAccountControl:1.2.840.113556.1.4.803:=8192)" #Exclude domain controllers
		$Searcher.Filter += "(!serviceprincipalname=*MSClusterVirtualServer*)" #Exclude MS Clustering objects
		$Searcher.Filter += "(!operatingSystem=Windows Server 2008*)" #Exclude legacy 2008 Operating system that does not support powershell remoting
		
		If ($HostsLDAPSearchFilter)
		{
			$Searcher.Filter += $HostsLDAPSearchFilter #Append any additional search filter from provider definition
		}
		$Searcher.Filter += ")"
		
		$DomainComputers = @()
		$DomainComputers = $Searcher.FindAll()
		If ($DomainComputers.Count -gt 0)
		{
			If ($HostsArray) { $HostsArray.Clear() }
			$HostsArray = @()
			foreach ($Computer in $DomainComputers)
			{
				$HostsArray += $Computer.Properties['dnshostname']	
			}
		}
	}
}

$HostAccounts = $HostsArray | ForEach-Object {
	$Hostname = $_.Trim();
	
	$WinRMNetworkParameters = Get-WinRMNetworkParameters -HostName $Hostname
	If ($WinRMNetworkParameters.Port)
	{
		$PSSession = Get-WinRMSession -WinRMNetworkParameters $WinRMNetworkParameters -Credential $Credential
		If ($PSSession)
		{
			Try
			{
				$Results = $null
				$Results = Invoke-Command -Session $PSSession -ArgumentList @($Hostname, $ExcludeDisabledAccountsInDiscovery) -ScriptBlock $RemoteHostScript
			}
			Catch
			{
				Write-EventLog -LogName Devolutions -EntryType Warning -Source "DVLS" -EventId 1 -Message $Error[0].Exception.ToString()
				Write-Error $Error[0].Exception.ToString()
			}
			
			Remove-PSSession -Session $PSSession
			$PSSession = $null
			if ($Results -ne $null -and $Results -ne "")
			{
				#Exclude Local Administrator account if managed by LAPS
				foreach ($account in $Results)
				{
					If (($account.UserName -eq "Administrator") -and (($domaincomputers | where {
									$_.Properties.dnshostname -eq $account.HostName
								}).Properties."mslaps-passwordexpirationtime" -ne $null))
					{
						$Results = $Results | where { $_.Username -ne $account.UserName }
					}
					
					#Exclude Failover Cluster Local Identity
					If ($account.UserName -eq "CLIUSR")
					{
						$Results = $Results | where { $_.Username -ne $account.UserName }
					}
				}
				return $Results
			}
		}
	}
}
return $HostAccounts

