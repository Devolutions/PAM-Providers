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
    [String]$HostsLDAPSearchFilter
)

$ScriptBlock = {
    Param ($Hostname,
        $ExcludeDisabled)
    
    Function Get-LocalUserADSI {
        
        Begin {
            
            #region  Helper Functions
            
            Function ConvertTo-SID {
                
                Param ([byte[]]$BinarySID)
                
                (New-Object  System.Security.Principal.SecurityIdentifier($BinarySID, 0)).Value
                
            }
            
            Function Convert-UserFlag {
                
                Param ($UserFlag)
                
                $List = New-Object  System.Collections.ArrayList
                
                Switch ($UserFlag) {
                    
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
        
        Process {
            $adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
            
            $adsi.Children | Where-Object { $_.SchemaClassName -eq 'user' } | ForEach-Object {
                
                [pscustomobject]@{
                    
                    Name        = $_.Name[0]
                    Description = $_.Description[0]
                    SID         = ConvertTo-SID -BinarySID $_.ObjectSID[0]
                    UserFlags   = Convert-UserFlag -UserFlag $_.UserFlags[0]
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
    
    Try {
        
        If ($ExcludeDisabled) {
            $LocalAccounts = Get-LocalUserADSI | Where-Object { $_.UserFlags -notmatch 'ACCOUNTDISABLE' } -ErrorAction 'Stop'
        } Else {
            $LocalAccounts = Get-LocalUserADSI -ErrorAction 'Stop'
        }
        
        $Accounts = $LocalAccounts | ForEach-Object {
            [PSCustomObject]@{
                'Username'     = $_.Name
                'Password'     = "password"
                'HostName'     = $Hostname
                'Hostname/SID' = $Hostname + "/" + $_.SId
                'SID'          = $_.SId
                'Description'  = $_.Description
            }
        }
        Write-Output $Accounts
    } Catch {
        Write-Error "LocalAccount failed to be retrieved on host $Hostname"
    }
    
}

Try {
    $Credential = New-Object System.Management.Automation.PSCredential @($LoginUsername, $LoginPassword)
    $HostsArray = $Hosts -split "[ ,;]"
    
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
    Import-Module NetTCPIP
    
    #If a single host is specified and that host is also listening on port 636 it is likely a domain controller, in which case enumerating local accounts would be redundant
    #So instead enumerate active domain computers for the list of hosts to query for local accounts
    If (($HostsArray.Count -eq 1) -and ((Test-NetConnection $HostsArray[0] -Port 636).TcpTestSucceeded)) {
        $DomainFQDN = $HostsArray[0]
        #ForEach ($level in ($DomainFQDN -Split ("\\.")))
        #{
        #    $DomainDN += ",DC=" + $level
        #}
        #$DomainDN = $DomainDN.TrimStart(",")
        
        Try {
            $ADSI = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$DomainFQDN`:636", $Credential.UserName, $Credential.GetNetworkCredential().Password) -ErrorAction Stop
            [void]$ADSI.ToString()
        } catch [System.Management.Automation.RuntimeException] {
            Write-Error "Unable to connect to $DomainDN"
        } catch {
            Write-Error $error[0].Exception.ToString()
        }
        
        If ($ADSI.distinguishedName -ne "") {
            $Searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher($ADSI)
            $Searcher.Filter = "(&(objectclass=computer)" #Find only computer objects
            $Searcher.Filter += "(!useraccountcontrol:1.2.840.113556.1.4.804:=2)" #Exclude disable accounts
            $Searcher.Filter += "(!userAccountControl:1.2.840.113556.1.4.803:=8192)" #Exclude domain controllers
            $Searcher.Filter += "(!serviceprincipalname=*MSClusterVirtualServer*)" #Exclude MS Clustering objects
            If ($HostsLDAPSearchFilter) {
                $Searcher.Filter += $HostsLDAPSearchFilter #Append any additional search filter from provider definition
            }
            $Searcher.Filter += ")"

            
            $DomainComputers = $Searcher.FindAll()
            If ($DomainComputers.Count -gt 0) {
                $HostsArray.Clear()
                $HostsArray = @()
                foreach ($Computer in $DomainComputers) {
                    $HostsArray += $Computer.Properties['dnshostname']    
                }
            }
        }
    }
    
    
    $HostAccounts = $HostsArray | ForEach-Object {
        $Hostname = $_.Trim();
        
        if ($Hostname -eq $null -or $Hostname -eq "") {
            return
        }
        #Write-Output $hostname
        If ((Test-NetConnection $Hostname -Port 5985).TcpTestSucceeded) {
            return Invoke-Command -ComputerName $Hostname -Credential $Credential -ArgumentList @($Hostname, $ExcludeDisabledAccountsInDiscovery) -ScriptBlock $ScriptBlock -ErrorAction 'Stop'
        } Else {
            If ((Test-NetConnection $Hostname -Port 5986).TcpTestSucceeded) {
                return Invoke-Command -ComputerName $Hostname -Credential $Credential -ArgumentList @($Hostname, $ExcludeDisabledAccountsInDiscovery) -ScriptBlock $ScriptBlock -UseSSL -Port 5986 -ErrorAction 'Stop'
            }
        }
    }
    
    return $HostAccounts
} catch {
    Write-Error $error[0].Exception.ToString()
}