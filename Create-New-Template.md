
The Template Providers page can be found in the Providers page.
*Administration/PrivilegedAccess/Provider/ProviderTemplate*

![alt text](./Images/6b59fb3e-9b89-4b76-887b-fe769598462c.png)


Then we create a new template

![alt text](./Images/43998304-fcd3-455e-9727-6b279f40e141.png)

We only have the choice to implement 3 actions, each of which will have its own script.

-   **Password rotation**, to reset account passwords.
    
-   **Heartbeat**, to synchronize accounts.
    
-   **Account discovery**, for scanning.
    
![alt text](./Images/800b4563-d81d-4733-87e0-777846ed7402.png)

We then determine the fields that the accounts and providers will implement.

Types are:

-   Username (string)  
-   Password (string)   
-   Description (string)   
-   UniqueIdentifier (string)  
-   String  
-   Int  
-   Bool  
-   Sensitive Data (SecureString)

The **Mandatory** field is used to determine if the fields will be required for creation/edition.

![alt text](./Images/7638d41e-4aa4-4a64-b2b4-d39c82459bf7.png)

For each action, we insert its script and then we will map the properties of the provider/account that the script needs to work.

**Name**: Name of the variable in the script.

**Source**: If the value is provided by the provider or the account.

**Property**: The source property that will be injected into the script.

![alt text](./Images/43f7437a-9f04-4a3c-b6e6-748d77d10288.png)

We then create a provider with the new type we created and we can now use it.