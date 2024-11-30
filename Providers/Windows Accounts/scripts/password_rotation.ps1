[CmdletBinding()]
Param (
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$HostName,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$UserName,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$NewPassword,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][String]$LoginUsername,
    [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][SecureString]$LoginPassword,
    [Switch]$DebugOutput
)

$ScriptBlock = {
    Param ($UserNameParam, $NewPasswordParam)
    If ($DebugOutput) {
        Write-Verbose ("[Debug] Retrieving Local User, '{0}'" -F $UserNameParam) -Verbose:$True
    }

    # Microsoft.PowerShell.LocalAccounts module not available in 32-bit PowerShell on 64-bit systems.
    Try {
        $User = Get-LocalUser -Name $UserNameParam -ErrorAction 'Stop' -Verbose:$DebugOutput
    } Catch {
        Write-Error "Username Does Not Exist"
        Exit
    }

    If ($User) {
        If ($DebugOutput) {
            Write-Verbose ("[Debug] User, '{0}' has the status of '{1}' and description of, '{2}'" -F $User.Name, $User.Enabled, $User.Description) -Verbose:$True
        }

        Try {
            If ($DebugOutput) {
                Write-Verbose ("[Debug] Attempting Password Change of, '{0}'" -F $User.Name) -Verbose:$True
            }

            $User | Set-LocalUser -Password $NewPasswordParam -ErrorAction 'Stop' -Verbose:$DebugOutput
        } Catch {
            Write-Error ("Failed To Set Password: {0}" -F $Error[0].Exception.ToString())
            Exit
        }

        Write-Output "Success"
    } Else {
        Write-Error "Unknown User Error"
    }
}


Try {
    $Credential = New-Object System.Management.Automation.PSCredential @($LoginUsername, $LoginPassword)
    $PSSession = New-PSSession $HostName -Credential $Credential

    $Results = Invoke-Command -Session $PSSession -ArgumentList @($UserName, $NewPassword) -ScriptBlock $ScriptBlock -ErrorAction 'Stop'

    $PSSession | Remove-PSSession
} Catch {
    Switch -Wildcard ($Error[0].Exception.ToString().ToLower()) {
        "*The user name or password is incorrect*" {
            Write-Error ("Failed to connect to the Host '{0}' to reset the password for the account '{1}'. Please check the Privileged Account Credentials provided are correct." -F $HostName, $UserName)
            Break
        }
        "*cannot bind argument to parameter*" {
            Write-Error ("Failed to reset the local password for account '{0}' on Host '{1}' as it appears you may not have associated a Privileged Account Credential with the Password Reset script." -F $UserName, $HostName)
            Break
        }
        # Add other wildcard matches here as required
        Default {
            Write-Error ("Failed to reset the local Windows password for account '{0}' on Host '{1}'. Error = {2}" -F $UserName, $HostName, $Error[0].Exception)
            Break
        }
    }
}

If ($Results -EQ "Success") {
    Write-Output "Success"
} Else {
    Switch -Wildcard ($Results.ToString().ToLower()) {
        "*WinRM cannot complete the operation*" {
            Write-Error ("Failed to reset the local Windows password for account '{0}' on Host '{1} as it appears the Host is not online, or PowerShell Remoting is not enabled." -F $UserName, $HostName)
            Break
        }
        "*WS-Management service running*" {
            Write-Error ("Failed to reset the local Windows password for account '{0}' on Host '{1}' as it appears the Host is not online, or PowerShell Remoting is not enabled." -F $UserName, $HostName)
            Break
        }
        "*cannot find the computer*" {
            Write-Error ("Failed to reset the local Windows password for account '{0}' on Host '{1}' as it appears the Host is not online, or PowerShell Remoting is not enabled." -F $UserName, $HostName)
            Break
        }
        "*no logon servers available*" {
            Write-Error ("Failed to reset the local Windows password for account '{0}' on Host '{1}'. There are currently no logon servers available to service the logon request." -F $UserName, $HostName)
            Break
        }
        "*currently locked*" {
            Write-Error ("Failed to reset the local password for account '{0}' on Host '{1}'. The referenced account is currently locked out and may not be logged on to." -F $UserName, $HostName)
            Break
        }
        "*user name or password is incorrect*" {
            Write-Error ("Failed to reset the local password for account '{0}' on Host '{1}' as the Privileged Account password appears to be incorrect, or the account is currently locked." -F $UserName, $HostName)
            Break
        }
        "*username does not exist*" {
            Write-Error ("Failed to reset the local password for account '{0}' on Host '{1}' as the UserName does not exist." -F $UserName, $HostName)
            Break
        }
        # Add other wildcard matches here as required
        Default {
            Write-Error ("Failed to reset the local password for account '{0}' on Host '{1}'.Error = {2}." -F $UserName, $HostName, $Results)
            Break
        }
    }
}