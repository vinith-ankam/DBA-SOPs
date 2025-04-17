# pr_get_Logins - SQL Server Login Permissions Report

## Overview

`pr_get_Logins` is a stored procedure designed to generate a SQL Server login permissions report across all accessible databases in a SQL Server instance. This report provides an overview of login permissions, including database roles, policies, and other key details for each login. The report can be emailed to specified recipients or displayed directly in SQL Server Management Studio (SSMS).

## Table of Contents

1. [Prerequisites](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)
2. [Parameters](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)
3. [Usage Examples](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)
4. [Report Structure](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)
5. [Deployment](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)
6. [Notes](https://www.notion.so/58d74233e83447be8db952c71ff32a53?pvs=21)

---

## Prerequisites

- **SQL Server Database Mail**: The `CIMSAlerts` mail profile must be configured and enabled on the SQL Server instance to enable email functionality.
- **Permissions**: The executing user needs permission to access system views: `sys.server_principals`, `sys.database_permissions`, `sys.database_role_members`, and `sys.databases`.

## Parameters

| Parameter | Type | Description |
| --- | --- | --- |
| `@RecipientEmail` | NVARCHAR(MAX) | Email address of the recipient. If `NULL`, the report will be displayed in SSMS only. |
| `@LoginName` | NVARCHAR(128) | Optional. Filters the report by the specified login name if provided. |

## Usage Examples

### Example 1: Send Login Permissions Report via Email

```sql
EXEC [dbo].[pr_get_Logins] @RecipientEmail = 'team@domain.com';
```

This command sends the login permissions report for all logins to `team@domain.com`.

### Example 2: Filtered Report for a Specific Login

```sql
EXEC [dbo].[pr_get_Logins] @RecipientEmail = 'team@domain.com', @LoginName = 'specificLogin';
```

This filters the report to show only permissions for `specificLogin` and emails it to `team@domain.com`.

### Example 3: Display Report in SSMS (No Email)

```sql
EXEC [dbo].[pr_get_Logins];
```

When no recipient email is provided, the report is displayed in SSMS.

## Report Structure

The report is organized as follows:

| Column | Description |
| --- | --- |
| `slno` | Serial number for each login entry. |
| `instance_name` | The SQL Server instance name. |
| `login` | Login name. |
| `login_desc` | Description of the login type (e.g., SQL login, Windows login, group, etc.). |
| `db_access` | Permissions and roles assigned to the login in each database. |
| `is_disabled` | Indicates if the login is disabled (`1` for disabled, `0` for active). |
| `create_date` | Date the login was created. |
| `modify_date` | Last modification date for the login. |
| `default_database_name` | The login's default database. |
| `default_language_name` | The login's default language. |
| `is_policy_checked` | Indicates if password policy enforcement is enabled for the login. |
| `is_expiration_checked` | Indicates if password expiration enforcement is enabled for the login. |
| `snapshot_datetime` | Date and time the report snapshot was generated. |

The report is formatted as an HTML table if sent via email.

## Deployment

To deploy the stored procedure:

1. Copy the SQL script for `pr_get_Logins`.
2. Execute the script in the `AdminDB` database to create the stored procedure.
3. Verify the `CIMSAlerts` Database Mail profile is set up for email functionality.

## Notes

- Ensure the `CIMSAlerts` Database Mail profile is configured and accessible.
- The procedure aggregates permissions across all **online** databases. Adjustments may be required for complex environments.
- This report aids in monitoring and auditing SQL Server login permissions across databases, simplifying the process of identifying access issues and policy compliance.
