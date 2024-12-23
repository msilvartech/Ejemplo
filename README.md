# Databricks Integration with Entra ID

## Overview

This document outlines the process for integrating Databricks with Entra ID for user provisioning. This integration leverages Personal Access Tokens (PAT) for authentication, utilizes **SCIM** (System for Cross-domain Identity Management) for user management, and allows for scheduling automated or manual script execution to add users from specified Entra ID groups into Databricks.

## Prerequisites

1. **Databricks Workspace Access**: You must have administrative access to the Databricks workspace in order to generate Personal Access Tokens (PAT).
2. **Entra ID (Azure AD)**: Ensure that the required Azure AD group(s) exist and are populated with the necessary users.
3. **Key Vault**: The Databricks access token must be stored in an Azure Key Vault, and the identity running the script must have access to this secret.

---

## Step 1: Obtain the Databricks Personal Access Token

### 1.1 Generate Personal Access Token (PAT)

1. **Log in to Databricks** at [https://accounts.azuredatabricks.net](https://accounts.azuredatabricks.net).
2. Navigate to User Settings > Access Tokens.
3. Click Generate New Token.
4. Copy the generated token. Keep it secure.

### 1.2 Store the Token in Azure Key Vault

1. Place the token in an Azure Key Vault secret.
2. Grant access to the secret for the identity used by Function App XXX.

---

## Step 2: Configure the Script for Additional Databricks Instances

To configure the integration for a new Databricks instance, follow these steps:

### 2.1 Copy an Existing Script

1. Copy an existing Databricks integration script as a template from the configuration file (line 1-70).
2. Paste it below the last entry in the `SCIM AD Groups` configuration file.

### 2.2 Update the Parameters

Modify the script to point to the new Databricks instance and configure the relevant parameters. Specifically, update the following variables:

```Powershell
$databricksInstance: Set this to the URL of the Databricks workspace (e.g., "https://adb-6234138917436195.15.azuredatabricks.net").
$accessGroups: The Azure AD group whose members you want to add to Databricks.
$scimToken: The URL pointing to the Key Vault secret that contains the generated Personal Access Token.
```
---

## Step 3: Script Execution
The script is set up to run automatically and also present the opportunity to be triggered on demand.

### 3.1 Automatic Execution
The script have been scheduled to run XX times per day, the timing was decided based on the current needs and taking into consideration the replication delay on ENtra ID for new users.

### 3.2 Manual Trigger
The script can also be manually triggered whenever required to add users from the specified Azure AD group to Databricks. The function can be deployed by any member of the admin team.
| **Note**     |
|-----------|
| The process currently only adds users to the Databricks workspace based on their membership in the provided Azure AD group(s). This is not a synchronization process, meaning that users who are removed from the Azure AD group will not be automatically removed from Databricks. Any cleanup or removal of users from Databricks must be done manually.| 
---
![image](https://github.com/user-attachments/assets/1455b952-00fc-4830-8f8e-555c119a6559)

---

## Conclusion

This integration process looks to be an efficient access management via Azure AD groups, streamlining the addition of new users to Databricks. By automating the user provisioning process, organizations can achieve:

- **Simplified User Management:** Automatically adding users based on their membership in AD groups reduces manual intervention, ensuring that the right people have access at all times.
- **Improved Structure:** Managing access through AD groups allows for a more organized and scalable approach to user access control, particularly as teams grow.
- **Centralized Control:** By relying on Azure AD for group management, you maintain a centralized system for user access control, making it easier to track and manage users across multiple systems.

In future realeases it is expected to add the deletion of users that are not part of the alloweds group and provide standarization and compliance to the actual management. 

For additional assistance or questions, please refer to Cloud Horizontal team.

---
