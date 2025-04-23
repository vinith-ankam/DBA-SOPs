---
Title: "Truncate Table Partitioning"
Author: VIA
Date: 15/04/2025
Topic: Partition
---
#  Partition Table Truncate by using pr_partition_TruncateTable Stored Procedure

Here is a step-by-step guide to creating and using the  `pr_partition_TruncateTable` stored procedure.

This procedure is designed to truncate partitions based on specified retention criteria, ensuring efficient data management within partitioned tables.

**Procedure Overview:**

1. **Purpose:**
    
    The `pr_partition_TruncateTable` procedure truncates partitions of a specified table based on a retention value provided in months (`M`) or years (`Y`). It helps in maintaining data retention policies efficiently within partitioned tables.
    
2. **Functionality:**
    - **Dynamic Calculation:** Calculates the retention date based on the current date and the retention value (`M` for months, `Y` for years).
    - **Partition Identification:** Uses system views (`sys.dm_db_partition_stats`, etc.) to identify partitions containing data older than the calculated retention date.
    - **SQL Generation:** Constructs a `TRUNCATE TABLE` SQL statement dynamically for the identified partitions.
    - **Execution:** Executes the generated SQL statement to truncate the specified partitions, thereby managing data retention effectively.
3. **Example Usage:**
    - To retain data for the last 6 months:`EXEC pr_partition_TruncateTable 'dbo.ImportReceiptDetails', 'M', 6;`
4. **Benefits:**
    - Automates the process of partition maintenance based on defined data retention policies.
    - Improves performance by efficiently managing partitioned data without affecting the entire table.
5. **Implementation:**
    - The procedure is implemented using T-SQL and leverages SQL Server's partitioning capabilities.
    - It ensures that only partitions containing older data are truncated, optimizing storage and query performance.

### Step 1: Create the Stored Procedure

The stored procedure pr_partition_TruncateTable` truncates table partitions based on the given retention criteria. It takes the table name, unit (months or years), and retention value as input parameters.

[pr_Partition_TruncateTable.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_TruncateTable.sql)

### Step 2: Usage of the Stored Procedure

Now, let's use the stored procedure to truncate partitions in a partitioned table. We'll assume that you have a partitioned table named `dbo.ImportReceiptHeaders`.

### Example: Retaining Data for the Last 6 Months

```sql
-- Retain data for the last 6 months

   EXEC [dbo].[pr_partition_TruncateTable] 
    @TableName = 'ImportReceiptHeaders',        --ActivityLog
    @Unit = 'M', --M-Months , Y- Years
    @RetentionValue = 6 -Retaintion Months

```

This command will retain data for the last 6 months (excluding the current month) in the `dbo.ImportReceiptHeaders` table and truncate partitions for data older than 6 months.

### Example: Retaining Data for the Last 1 Year

```sql
-- Retain data for the last 1 year
EXEC pr_partition_TruncateTable 'dbo.ImportReceiptHeaders', 'Y', 1;

```
### Before

![image](https://github.com/user-attachments/assets/2970f1e7-84c7-41f9-9e06-c5fe05054867)

### Exec 

![image](https://github.com/user-attachments/assets/0e74a3e2-62a0-4baa-83e9-aa63d73951ec)

### After: 

![image](https://github.com/user-attachments/assets/8c9ba005-97f1-4ff1-ac42-3a5c76a68f08)


This command will retain data for the last 1 year (excluding the current month) in the `dbo.ImportReceiptHeaders` table and truncate partitions for data older than 1 year.

### How It Works

1. **Input Parameters:**
    - `@TableName`: The name of the table for which partitions need to be truncated.
    - `@Unit`: The unit of time ('M' for months, 'Y' for years).
    - `@RetentionValue`: The number of units to retain (e.g., 6 months, 1 year).
2. **Retention Date Calculation:**
    - The procedure calculates the retention date by subtracting the retention value from the current date. This date determines the cut-off for data retention.
3. **Partition Identification:**
    - The procedure identifies the partitions that contain data older than the retention date. It uses system views and joins to find the appropriate partitions.
4. **Dynamic SQL Construction:**
    - The procedure constructs a `TRUNCATE TABLE` statement with the identified partitions.
5. **Execution:**
    - The constructed SQL statement is executed to truncate the identified partitions.
6. **Debug Output:**
    - Debug statements are printed to help verify the procedure's execution flow and values.

By following this POC, you can create and use the `pr_partition_Truncate_table` stored procedure to manage table partitions based on retention criteria effectively.
