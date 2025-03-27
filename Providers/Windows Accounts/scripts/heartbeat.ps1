[CmdletBinding()]
param (
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$Username,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[SecureString]$Password,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$Hostname,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[String]$LoginUsername,
	[Parameter(Mandatory = $True)]
	[ValidateNotNullOrEmpty()]
	[SecureString]$LoginPassword
)

[System.Management.Automation.ScriptBlock]$RemoteHostScript = {
	param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[String]$Username,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[SecureString]$Password
	)
	Add-Type -AssemblyName System.DirectoryServices.AccountManagement
	#$obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$Hostname)
	$ct = [System.DirectoryServices.AccountManagement.ContextType]::Machine, $env:computername
	$opt = [System.DirectoryServices.AccountManagement.ContextOptions]::SimpleBind
	$obj = New-Object System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $ct
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
	$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

	$result = $obj.ValidateCredentials($Username, $UnsecurePassword)
	if ($result -ne $true)
	{
		Write-Error "The username or password does not match the credential on the machine";
	}

	Write-Output $result
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
			$Results = Invoke-Command -Session $PSSession -ArgumentList @($UserName, $Password) -ErrorVariable errmsg -ScriptBlock $RemoteHostScript
			if ($errmsg -ne $null -and $errmsg -ne "") {
                Write-Error $errmsg
            }
		}
		Catch
		{
			Write-Error $Error[0].Exception.ToString()
		}

		Remove-PSSession -Session $PSSession
		$PSSession = $null
		Write-Output $Results
	}
}
