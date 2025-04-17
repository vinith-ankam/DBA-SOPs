## **POC Document for CPU and RAM Alert Monitoring in SQL Server**

### **Objective:**

To monitor CPU and RAM usage on a SQL Server instance, log details to a dedicated table, and send email alerts when resource usage exceeds or returns to normal from predefined thresholds.

---

### **Prerequisites:**

1. **AdminDB Database**: This database should exist on the SQL Server instance to store monitoring data.
2. **Database Mail Profile**: Ensure a mail profile named `CIMSAlerts` exists and is configured for SQL Server Database Mail.
3. **Permissions**: Execute permissions for `sp_send_dbmail` and access to `sys.dm_os_sys_memory` and `sys.dm_os_schedulers`.

---

### **Steps and Scripts**

### Step 1: **Create Required Tables in AdminDB**

1. **Create `ServerStatus` Table**: This table stores the current status of CPU/memory utilization, allowing the system to track state changes.
  - [01.AdminDB_ServerStatus_Table.sql](https://github.com/vinithCIMS/DBA_POC-s/blob/main/Alerts/01.AdminDB_ServerStatus_Table.sql)
3. **Create `CPURAMUsageLog` Table**: This table logs each check with CPU and memory usage details.
- [02.AdminDB_CPURAMUsageLog_Table.sql](https://github.com/vinithCIMS/DBA_POC-s/blob/main/Alerts/02.AdminDB_CPURAMUsageLog_Table.sql)

### Step 2: **Create `pr_CPURAMAlert` Stored Procedure**

The procedure monitors CPU and memory usage, logs the data, and sends alerts when thresholds are crossed or restored.
- [03.msdb_pr_CPURAMAlert_Procedure.sql](https://github.com/vinithCIMS/DBA_POC-s/blob/main/Alerts/03.msdb_pr_CPURAMAlert_Procedure.sql)

### Step 3: **Create SQL Agent Job for Scheduled Monitoring**

1. **Create Job**:
    - Go to **SQL Server Agent** > **Jobs** > **New Job**.
2. **Configure Job Properties**:
    - Name: `Monitor_CPU_RAM_Usage`
    - Steps:
        - **Step 1**:
            - Type: `Transact-SQL Script (T-SQL)`
            - Command:
                
                ```sql
                EXEC msdb.dbo.pr_CPURAMAlert;
                ```
                
    - Schedule:
        - Frequency: Every 5 minutes (or as per your monitoring requirement).
3. **Enable the Job**.

### Step 4: **Testing and Validation**

1. **Insert Low Threshold Values for Testing**:
    - Temporarily set low values for `@CPULimit` (e.g., 5) and high values for `@MemoryLimit` (e.g., 15000) in the procedure to simulate alerts under regular conditions.
2. **Run Procedure Manually**:
    - Execute the procedure:
        
        ```sql
        EXEC msdb.dbo.pr_CPURAMAlert;
        ```
        
3. **Check Results**:
    - **Email Alert**: Verify an alert email is sent.
    - **Database Logs**: Check `AdminDB.dbo.CPURAMUsageLog` and `AdminDB.dbo.ServerStatus` for correct entries.
4. **Restore Normal Thresholds**:
    - Reset `@CPULimit` and `@MemoryLimit` in the procedure to realistic values after testing.

---

### **Post-Execution Verification**

1. **Monitor Email Alerts**: Confirm emails are sent only when the threshold is exceeded or restored.
2. **Check `CPURAMUsageLog`**: Verify that each CPU/memory check is logged with appropriate details.
3. **Review `ServerStatus` Table**: Confirm it accurately reflects the server’s threshold status.

---

This completes the POC for monitoring and alerting CPU and memory usage on SQL Server.
