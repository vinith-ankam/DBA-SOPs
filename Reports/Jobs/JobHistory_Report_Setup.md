# POC Document: SQL Server Job History Report Setup with Recurring Job

## Objective

This POC document outlines the steps to set up a stored procedure (`pr_Jobs_GetInfo`) that retrieves SQL Server job history information based on specified time ranges (hours, days, etc.), and how to configure a SQL Server Agent job to run this stored procedure every 3 hours and send the job history report via email.

---

## 1. Prerequisites

### 1.1 SQL Server Environment

- **SQL Server version**: SQL Server 2019 or later
- **SQL Server Agent**: Enabled and running
- **Database**: Stored procedure will be created in **msdb** (or any user database).
- **DB Mail Profile**: A DB Mail profile, such as `CIMSAlerts`, must be configured in SQL Server.

### 1.2 Permissions

- The user creating the stored procedure and SQL Agent job should have sufficient permissions, including:
    - `EXECUTE` permission on the `msdb.dbo.sp_send_dbmail` procedure (for sending emails).
    - Permissions to create and schedule SQL Server Agent jobs.

---

## 2. Stored Procedure Setup

### 2.1 Create the Stored Procedure

1. Open SQL Server Management Studio (SSMS).
2. Connect to the SQL Server instance where the procedure will be created.
3. Execute the following script to create the stored procedure `pr_Jobs_GetInfo` in the desired database (e.g., **msdb**):
   -[pr_Jobs_GetInfo](https://github.com/vinithCIMS/DBA_POC-s/blob/main/Jobs/pr_Jobs_GetInfo.sql)
### 2.2 Verifying the Stored Procedure

- After creating the procedure, run a few test executions to verify the output:

### Example 1: Get Failed Jobs from the Last 3 Hours (SSMS Output):

```sql
EXEC pr_Jobs_GetInfo
    @Hours = 3,
    @Status = 'Failed';
```

### Example 2: Get Failed Jobs from the Last 3 Hours (Email Output):

```sql
EXEC pr_Jobs_GetInfo
    @Hours = 3,
    @Status = 'Failed',
    @Email = 'recipient@example.com';
```

---

## 3. SQL Server Agent Job Setup

### 3.1 Create a New SQL Server Agent Job

1. **Open SQL Server Management Studio (SSMS)**.
2. **Expand** the SQL Server Agent node.
3. **Right-click** on **Jobs** and choose **New Job**.
4. In the **New Job** window, under the **General** tab, enter:
    - **Name**: `SQL Job History Report Every 3 Hours`
    - **Owner**: Specify the job owner (e.g., `sa`).

### 3.2 Create Job Steps

1. **Click** on the **Steps** tab.
2. **Click** on **New** to add a new step:
    - **Step name**: `Send Job History Report`
    - **Type**: `Transact-SQL script (T-SQL)`
    - **Database**: `msdb` (or the database where the procedure is located)
    - **Command**: Enter the following script to execute the stored procedure and send the report via email every 3 hours:

```sql
EXEC pr_Jobs_GetInfo
    @Hours = 3,
    @Status = 'Failed',  -- Change status as needed (e.g., 'Succeeded', 'All', etc.)
    @Email = 'recipient@example.com';  -- Replace with actual recipient email
```

1. **Click OK** to save the step.

### 3.3 Configure Job Schedule

1. **Click** on the **Schedules** tab.
2. **Click New** to create a new schedule:
    - **Name**: `Every 3 Hours`
    - **Frequency**: Recurring
    - **Occurs**: Every day
    - **Occurs every**: 3 hours
    - **Start date**: Set the desired start date and time.
3. **Click OK** to save the schedule.

### 3.4 Enable Notifications (Optional)

1. **Click** on the **Notifications** tab.
2. **Select** options such as:
    - **Email**: To notify on success/failure (if needed).
3. **Click OK** to create the job.

### 3.5 Verify the Job Schedule

- In SSMS, under SQL Server Agent -> Jobs, verify that the job is scheduled to run every 3 hours.
- You can manually run the job by **right-clicking** on the job and selecting **Start Job at Step** to test it.

---

## 4. Example Job Run Results

### 4.1 SSMS Output

When running the job from SSMS with this script:

```sql
EXEC pr_Jobs_GetInfo
    @Hours = 3,
    @Status = 'Failed';
```

The result should display a list of **failed jobs** from the last 3 hours.

### 4.2 Email Output

When the job runs automatically every 3 hours, the recipients should receive an email similar to the following:

### Email Subject:

```sql
SQL Job History Report of YourServerName - Last 3 Hour(s)
```

### Email Body:

```sql
Dear Team,

Please find below the SQL Failed Job History Report from Last 3 Hour(s):

Job Name      | Run Date    | Run Time | Status   | Message
---------------------------------------------------------------
JobName1      | 2024-OCT-18 | 10:15:00 | Failed   | Job failed due to error...
JobName2      | 2024-OCT-18 | 08:00:00 | Failed   | Job failed due to timeout...

Regards,
DBA Team
```

If no failed jobs are found, the email body will display:

```sql
Dear Team,

There were no SQL Failed Job History Reports from the Last 3 Hour(s).

Regards,
DBA Team
```

---

## 5. Conclusion

By following the steps outlined in this document, you can set up a stored procedure to fetch SQL job history data and configure a SQL Server Agent job that sends this information via email every 3 hours. This setup helps automate monitoring of job executions and enhances visibility for timely reporting.
