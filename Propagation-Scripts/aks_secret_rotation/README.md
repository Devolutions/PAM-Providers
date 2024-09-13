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
