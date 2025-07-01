# Remove-GraphUserAuthMethods

This PowerShell script automates the removal of legacy software OATH authentication methods from users in Microsoft Entra ID (Azure AD) using the Microsoft Graph PowerShell SDK. See more here:

https://learn.microsoft.com/en-us/graph/api/softwareoathauthenticationmethod-delete?view=graph-rest-1.0&tabs=powershell

## Features

- Prompts for dry-run mode to preview changes before applying them
- Logs all actions to a CSV file for auditing
- Implements retry logic for Microsoft Graph API throttling (HTTP 429)
- Uses delegated permissions with `Connect-MgGraph`

## Prerequisites

- PowerShell 7+
- Microsoft Graph PowerShell SDK installed:
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser -Force
  ```

## Required Permissions

The script uses delegated permissions. The signed-in user must have one of the following roles:

- Authentication Administrator
- Privileged Authentication Administrator

The following Microsoft Graph delegated permissions must be granted:

- User.Read.All
- UserAuthenticationMethod.ReadWrite.All

## Setup

1. Open PowerShell as Administrator.
2. Run the script using:

```powershell
.\\Remove-GraphUserAuthMethods.ps1
```

3. When prompted, choose whether to run in dry-run mode.

## Output 

An audit log is saved to audit_log.csv in the script directory.
Each row includes:
- UserPrincipalName
- Action taken (or previewed)
- Method ID
- Status (Success, Failed, Preview)

## Example

| UserPrincipalName | Action              | MethodId | Status  |
|-------------------|---------------------|----------|---------|
| user1@example.com | DryRun-RemoveMethod | a1       | Preview |
| user2@example.com | RemoveMethod        | a2       | Success |

## Notes

- The script uses exponential backoff when encountering throttling (HTTP 429).
- You can filter users or extend the script to target specific groups or domains.
