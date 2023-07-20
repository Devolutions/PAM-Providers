## Windows Accounts Provider

This provider allow you to manage local windows account on many hosts. A Windows Account provider already exists built-in in Devolutions Server, but that provider allow you to manage only one host. This AnyIdentity provider will allow you to manage many hosts, all managed by the same provider.

## Prerequisites

1 - Ensure that WinRM is properly configured and that all remote machines are added in the Trusted Hosts list as stated in ![WinRM and Trusted Hosts List](https://docs.devolutions.net/kb/devolutions-server/how-to-articles/winrm-trustedhostslist/).

2 - The provider has to be configured with credential that can be used to access all remote machines. It can be a domain user if all machines are on the same domains or it can also be a local account existing for all machines. 

## Configuration

The Windows Accounts Provider is easy to configure. It requires credential that will be used to to access all remote machines and a list of all machines that you want to manage. That host list is only your hostnames separated by comma, semicolon or space.