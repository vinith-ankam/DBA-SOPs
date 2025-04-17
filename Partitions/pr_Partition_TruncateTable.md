# Proof of Concept (POC) Document for Partition Table Truncate by using pr_partition_Truncate_table Stored Procedure

Here is a step-by-step guide to creating and using the  `pr_partition_Truncate_table` stored procedure.

This procedure is designed to truncate partitions based on specified retention criteria, ensuring efficient data management within partitioned tables.

**Procedure Overview:**

1. **Purpose:**
    
    The `pr_partition_Truncate_table` procedure truncates partitions of a specified table based on a retention value provided in months (`M`) or years (`Y`). It helps in maintaining data retention policies efficiently within partitioned tables.
    
2. **Functionality:**
    - **Dynamic Calculation:** Calculates the retention date based on the current date and the retention value (`M` for months, `Y` for years).
    - **Partition Identification:** Uses system views (`sys.dm_db_partition_stats`, etc.) to identify partitions containing data older than the calculated retention date.
    - **SQL Generation:** Constructs a `TRUNCATE TABLE` SQL statement dynamically for the identified partitions.
    - **Execution:** Executes the generated SQL statement to truncate the specified partitions, thereby managing data retention effectively.
3. **Example Usage:**
    - To retain data for the last 6 months:`EXEC pr_partition_Truncate_table 'dbo.ImportReceiptDetails', 'M', 6;`
4. **Benefits:**
    - Automates the process of partition maintenance based on defined data retention policies.
    - Improves performance by efficiently managing partitioned data without affecting the entire table.
5. **Implementation:**
    - The procedure is implemented using T-SQL and leverages SQL Server's partitioning capabilities.
    - It ensures that only partitions containing older data are truncated, optimizing storage and query performance.

### Step 1: Create the Stored Procedure

The stored procedure `pr_partition_Truncate_table` truncates table partitions based on the given retention criteria. It takes the table name, unit (months or years), and retention value as input parameters.

```sql
CREATE PROCEDURE pr_partition_Truncate_table
    @TableName NVARCHAR(256),
    @Unit CHAR(1), -- 'M' for months, 'Y' for years
    @RetentionValue INT
AS
BEGIN
    DECLARE @FullTableName NVARCHAR(513);
    DECLARE @TruncateSQL NVARCHAR(MAX);
    DECLARE @CurrentDate DATE = GETDATE();
    DECLARE @RetentionDate DATE;
    DECLARE @StartingPartition INT;
    DECLARE @EndingPartition INT;

    -- Debug: Start of procedure
    PRINT 'Starting pr_partition_Truncate_table procedure';
    PRINT 'Table Name: ' + @TableName;
    PRINT 'Retention Value: ' + CAST(@RetentionValue AS NVARCHAR);
    PRINT 'Unit: ' + @Unit;

    -- Calculate the retention date based on the current date and retention value
    IF @Unit = 'M'
        SET @RetentionDate = DATEADD(MONTH, -@RetentionValue, DATEADD(MONTH, DATEDIFF(MONTH, 0, @CurrentDate), 0)); -- Truncate the current date to the start of the month and then subtract the retention period in months
    ELSE IF @Unit = 'Y'
        SET @RetentionDate = DATEADD(YEAR, -@RetentionValue, DATEADD(MONTH, DATEDIFF(MONTH, 0, @CurrentDate), 0)); -- Truncate the current date to the start of the month and then subtract the retention period in years
    ELSE
        BEGIN
            PRINT 'Unsupported unit. Use "M" for months or "Y" for years.';
            RETURN;
        END

    -- Debug: Retention date
    PRINT 'Retention Date: ' + CAST(@RetentionDate AS NVARCHAR);

    -- Get the full table name
    SELECT @FullTableName = QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@TableName))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@TableName)));

    -- Debug: Full table name
    PRINT 'Full Table Name: ' + @FullTableName;

    -- Find the starting and ending partition numbers
    SELECT
        @StartingPartition = MIN(pstats.partition_number),
        @EndingPartition = MAX(pstats.partition_number)
    FROM sys.dm_db_partition_stats AS pstats
    INNER JOIN sys.partitions AS p ON pstats.partition_id = p.partition_id
    INNER JOIN sys.destination_data_spaces AS dds ON pstats.partition_number = dds.destination_id
    INNER JOIN sys.data_spaces AS ds ON dds.data_space_id = ds.data_space_id
    INNER JOIN sys.partition_schemes AS ps ON dds.partition_scheme_id = ps.data_space_id
    INNER JOIN sys.partition_functions AS pf ON ps.function_id = pf.function_id
    LEFT JOIN sys.partition_range_values AS prv ON pf.function_id = prv.function_id
        AND pstats.partition_number = (CASE pf.boundary_value_on_right WHEN 0 THEN prv.boundary_id ELSE (prv.boundary_id + 1) END)
    WHERE pstats.object_id = OBJECT_ID(@TableName)
      AND prv.value IS NOT NULL
      AND CONVERT(DATE, prv.value) < @RetentionDate;

    -- Debug: Starting and Ending partitions
    PRINT 'Starting Partition: ' + CAST(@StartingPartition AS NVARCHAR);
    PRINT 'Ending Partition: ' + CAST(@EndingPartition AS NVARCHAR);

    -- Construct the TRUNCATE TABLE statement
    IF @StartingPartition IS NOT NULL AND @EndingPartition IS NOT NULL
    BEGIN
        SET @TruncateSQL = 'TRUNCATE TABLE ' + @FullTableName + ' WITH (PARTITIONS (' + CAST(@StartingPartition AS NVARCHAR) + ' TO ' + CAST(@EndingPartition AS NVARCHAR) + '));';

        -- Debug: Generated SQL
        PRINT 'Generated SQL: ' + @TruncateSQL;

        -- Execute the dynamic SQL to truncate the partitions
        EXEC sp_executesql @TruncateSQL;
    END
    ELSE
    BEGIN
        PRINT 'No partitions to truncate.';
    END

    -- Debug: End of procedure
    PRINT 'Completed pr_partition_Truncate_table procedure';
END;
GO

```

### Step 2: Usage of the Stored Procedure

Now, let's use the stored procedure to truncate partitions in a partitioned table. We'll assume that you have a partitioned table named `dbo.ImportReceiptDetails`.

### Example: Retaining Data for the Last 6 Months

```sql
-- Retain data for the last 6 months
EXEC pr_partition_Truncate_table 'dbo.ImportReceiptDetails', 'M', 6;

```

This command will retain data for the last 6 months (excluding the current month) in the `dbo.ImportReceiptDetails` table and truncate partitions for data older than 6 months.

### Example: Retaining Data for the Last 1 Year

```sql
-- Retain data for the last 1 year
EXEC pr_partition_Truncate_table 'dbo.ImportReceiptDetails', 'Y', 1;

```

This command will retain data for the last 1 year (excluding the current month) in the `dbo.ImportReceiptDetails` table and truncate partitions for data older than 1 year.

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
