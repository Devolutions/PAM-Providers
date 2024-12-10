[CmdletBinding()]
Param (
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$HostName,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$UserName,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[SecureString]$NewPassword,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$LoginUsername,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[SecureString]$LoginPassword,
	[Switch]$DebugOutput
)

[System.Management.Automation.ScriptBlock]$RemoteHostScript = {
	Param ($UserNameParam,
		$NewPasswordParam)
	If ($DebugOutput)
	{
		Write-Verbose ("[Debug] Retrieving Local User, '{0}'" -F $UserNameParam) -Verbose:$True
	}
	
	# Microsoft.PowerShell.LocalAccounts module not available in 32-bit PowerShell on 64-bit systems.

	$User = [ADSI] "WinNT://./$UserNameParam"
	If (-not ($?))
	{
		Write-Error "Username Does Not Exist"
		Exit
	}
	
	If ($User)
	{
		If ($DebugOutput)
		{
			Write-Verbose ("[Debug] User, '{0}' has the status of '{1}' and description of, '{2}'" -F $User.Name, $User.Enabled, $User.Description) -Verbose:$True
		}
		
		Try
		{
			If ($DebugOutput)
			{
				Write-Verbose ("[Debug] Attempting Password Change of, '{0}'" -F $User.Name) -Verbose:$True
			}
			$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPasswordParam)
			$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
			$User.SetPassword($UnsecurePassword)
		}
		Catch
		{
			Write-Error ("Failed To Set Password: {0}" -F $Error[0].Exception.ToString())
			Exit
		}
		
		Write-Output "Success"
	}
	Else
	{
		Write-Error "Unknown User Error"
	}
}


function Get-WinRMNetworkParameters
{
	param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[String]$HostName)
	
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
						Write-Error $Error[0].Exception.ToString()
						return
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
						Write-Error $Error[0].Exception.ToString()
						return
					}
					return $SessionParameters
				}
				
				default
				{
					Write-Error "No connectivity on TCP ports 5985 or 5986 to $Hostname"
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
				Write-Error $Error[0].Exception.ToString()
			}
		}
	}
	If ($RemoteSession.State -eq 'Opened')
	{
		return $RemoteSession
	}
}

$WinRMNetworkParameters = Get-WinRMNetworkParameters -HostName $Hostname
If ($WinRMNetworkParameters.Port)
{
	$Credential = New-Object System.Management.Automation.PSCredential @($LoginUsername, $LoginPassword)
	$PSSession = Get-WinRMSession -WinRMNetworkParameters $WinRMNetworkParameters -Credential $Credential
	If ($PSSession)
	{
		Try
		{
			$Results = Invoke-Command -Session $PSSession -ArgumentList @($UserName, $NewPassword) -ScriptBlock $RemoteHostScript
		}
		Catch
		{
			Write-Error $Error[0].Exception.ToString()
		}
		
		Remove-PSSession -Session $PSSession
		$PSSession = $null
		If ($Results -EQ "Success")
		{
			Write-Output "Success"
		}
	}
}

