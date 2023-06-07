# Propagation Script

Propagation scripts allow you to execute a custom PowerShell script at the end of a privileged account password change operation. This enables you, for example, to update the password of a service on a remote machine or update a secret in Azure KeyVault.

## Architecture of a propagation script

A propagation script requires three components to work properly.
1. **Propagation Template**   
The template serves as the foundation of the script. It is where various variables are declared, which are later used in the script. These variables will be filled in the configuration section of the propagation script.   
This is also where you will find the PowerShell script itself.
2. **Propagation configuration**   
The configuration is where the values of the variables are provided. It is the place to specify the specific values for the variables used in the template.
3. **Link between the resource and the configuration**   
Subsequently, one or more configurations are attached to a privileged account. This ensures that the propagation is executed when the password is updated for the associated account or for accounts within the parent folder.

## Different types of variables
There are two types of variables to configure, referred to as "properties" in the interface.
1. **Propagation properties**   
These are the "global" properties of the script. Regardless of the account or folder it is linked to, the specified values remain the same.
2. **Mapping properties**   
These properties allow defining values for each privileged account type. Typically, these properties are mapped to a known field of the account type. It is also possible to define arbitrary values, although it is less common.

## Usage context
- You can attach one or multiple scripts to a privileged account. There is no limit to the number of scripts that can be attached to the same resource.
- If an account has a script attached scripts will be executed when the account's password is updated.
- To ensure a script is executed, it is crucial to configure the mapping properties for the account type the script is attached to. Otherwise, the script will be ignored.

### How to create a propagation script
If you have a specific script in mind and are familiar with PowerShell, you can create your own template and then create propagation configurations using it.

### How to import a propagation script
You can choose to download one of the available templates that matches your needs from this repository, import it, and then create one or more propagation configurations based on these templates.

Follow the instructions below that match your needs:
- [Download and import Devolutions provided template](./Download-and-import.md)
- [Create a template](./Create-A-Template.md) (for advanced users).
- [Configure propagation based on a template](./Configure-Propagation.md) (either downloaded or manually created).
- [Use a configuration](./Use-A-Configuration.md)