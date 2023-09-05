## Windows Accounts Provider

This provider allow you to manage local windows account on many hosts. A Windows Account provider already exists built-in in Devolutions Server, but that provider allow you to manage only one host. This AnyIdentity provider will allow you to manage many hosts, all managed by the same provider.

## Prerequisites

1 - Ensure that WinRM is properly configured and that all remote machines are added in the Trusted Hosts list as stated in [WinRM and Trusted Hosts List](https://docs.devolutions.net/kb/devolutions-server/how-to-articles/winrm-trustedhostslist/).  

2 - The provider has to be configured with a credential that can be used to access all remote machines. It can be a domain user if all machines are on the same domains or it can also be a local account existing for all machines. 

3 - The provider will use WinRM to connect to hosts (on TCP port 5985 or 5986) and enumerate local user accounts, which requires the respective Login credential to have sufficient privilege.  At a minimum, membership of the local group 'Remote Management Users' is required to remotely connect using PowerShell and discover/validate local user accounts.  In order to change/reset local account passwords, local administrator privilege would be required.

4 - By default the provider expects a list of hostnames to query for local user accounts.  The host list can either be a collection of individual hostnames (separated by comma, semicolon or space), or alternatively a domain FQDN (i.e. domain.local).  

## Configuration

The Windows Accounts Provider is easy to configure. It requires credential that will be used to to access all remote machines. 

If using a domain FQDN, by default disabled computer accounts will be excluded, as will domain controllers and Microsoft clustering computer objects.  

Currently, the template requires the 'HostsLDAPSearchFilter' provider parameter to be populated (it cannot be left blank/empty).  The paramater is ignored when using a list of individual hostnames, but still needs to be populated with something (this will be fixed in future versions of DVLS).  

When using a domain FQDN and to limit hostname discovery to server objects, specify the filter string as '(operatingsystem=*Server*)', with the quotation marks excluded.  Further examples of LDAP filter stings can be found at https://www.rfc-editor.org/rfc/rfc4515.txt 
