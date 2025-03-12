# Setup and Requirements for Kubernetes Secret Management Script

This guide provides the steps and tools required to set up a server for managing Kubernetes secrets via a PowerShell script. The script interacts with Azure and Kubernetes using a service principal for automated secret management.

## Requirements
Ensure the following tools are installed on your server:

- **kubectl**: Command-line tool for Kubernetes.
- **kubelogin**: Azure Active Directory integration for Kubernetes clusters.
- **Azure CLI**: Interface for managing Azure resources.

### Verifying Installations

After installation, verify the tools are working with the following commands:
```powershell
kubectl version --client
kubelogin --version
az version
```

## Setup

- **IP Restrictions**: Ensure your server has the necessary network access to reach the Kubernetes API and Azure services.
- **Tools Availability**: Verify that the required command-line tools (`kubectl`, `kubelogin`, `Azure CLI`) are accessible from the DVLS application.
- **Service Principal**: Set up a service principal with **WRITE** permissions on your Kubernetes cluster.

## Testing the Script
To test the script on your server's console, use the following PowerShell command:

```powershell
.\YourScript.ps1 -AzureTenantID "your-tenant-id" `
                 -AzureApplicationID "your-application-id" `
                 -AzureApplicationSecret (ConvertTo-SecureString "your-client-secret" -AsPlainText -Force) `
                 -Cluster "your-cluster-context" `
                 -Deployment "your-deployment" `
                 -Namespace "your-namespace" `
                 -SecretName "your-secret-name" `
                 -ConfigPath "C:\path\to\kubeconfig" `
                 -NewPassword (ConvertTo-SecureString "your-new-password" -AsPlainText -Force) `
                 -SubscriptionID "your-subscription-id"
```
### Note:
Replace the placeholders (e.g., `"your-tenant-id"`, `"your-cluster-context"`, etc.) with the actual values for your environment to ensure correct script execution.

## Properties

| Property             | Description                                                                 | Mandatory | Example                                    |
|----------------------|-----------------------------------------------------------------------------|-----------|--------------------------------------------|
| AzureTenantID        | The tenant ID of your organizatiobn. | Yes       | "1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p"     |
| AzureApplicationID   | The ID of the service principal in Azure AD | Yes       | "abcdef12-3456-7890-abcd-ef1234567890"     |
| AzureApplicationSecret | The client secret of the service principal. This is used for authenticating the application with Azure AD. | Yes       | (SecureString)                             |
| Cluster              | The name of the Kubernetes cluster where the application is deployed.        | Yes       | "my-k8s-cluster"                           |
| Deployment           | The name of the deployment resource in your Kubernetes cluster.              | Yes       | "my-app-deployment"                        |
| Namespace            | The Kubernetes namespace where the deployment is located.                    | Yes       | "production"                               |
| SecretName           | The name of the secret resource in Kubernetes that contains sensitive information. | Yes       | "my-app-secret"                            |
| ConfigPath           | The file path to the `kubectl` configuration file used for interacting with the Kubernetes cluster. | Yes       | "/home/user/.kube/config"                  |
| NewPassword          | The new password for the user (this field may store the new password when required for user updates). | Yes       | (SecureString)                             |
| SubscriptionID       | The Azure subscription ID under which the resources are provisioned.         | Yes       | "12345678-90ab-cdef-1234-567890abcdef"     |
