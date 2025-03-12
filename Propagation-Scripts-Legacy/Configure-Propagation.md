# Configure propagation based on a template

## Context

Whether you have downloaded or created a template manually, you need to configure a propagation afterwards.   
In this document, we are following up on the template created in the [Create a new Template](./Create-A-Template.md) section, but the process is the same if you have downloaded a pre-designed template.

## Configuration

Go to the section **Administration -> Privileged Access -> Propagation**   
![alt text](../Images/propagation-scripts/admin-privileged-access-menu.png)
![alt text](../Images/propagation-scripts/propagation-menu.png)

Then click on the icon to create a new configuration.   
![alt text](../Images/propagation-scripts/configuration/config-step1.png)

In the window that appears, select the template from which you want to create the configuration.   
![alt text](../Images/propagation-scripts/configuration/config-step2.png)

In the General tab, give a name to your configuration.   
![alt text](../Images/propagation-scripts/configuration/config-step3.png)

In the Propagation Properties tab, fill in the information for the remote machine.   
![alt text](../Images/propagation-scripts/configuration/config-step4.png)

In the Property Mapping tab, add a configuration for the type of privileged account you want to support.   
![alt text](../Images/propagation-scripts/configuration/config-step5.png)
![alt text](../Images/propagation-scripts/configuration/config-step6.png)

In the opened window, select the fields of the account (or its provider) that you want to associate with your variables.   
![alt text](../Images/propagation-scripts/configuration/config-step7.png)

Finally, save your new configuration.   
![alt text](../Images/propagation-scripts/configuration/config-step8.png)

You can now move on to the last step, which involves attaching your configuration to a privileged account: [Use a configuration](./Use-A-Configuration.md)