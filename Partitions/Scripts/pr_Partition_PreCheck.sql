/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_PreCheck') is not null
  drop Procedure pr_Partition_PreCheck;
Go

/*------------------------------------------------------------------------------
--Usage :  
--DB Level:
exec   pr_Partition_PreCheck @DBName='JLCA_CIMSProd' ;
--Table: 
exec   pr_Partition_PreCheck @DBName='JLCA_CIMSProd' , @TargetTable='ActivityLog' ;
------------------------------------------------------------------------------*/
CREATE PROCEDURE pr_Partition_PreCheck
    @DBName SYSNAME = NULL,
    @TargetTable SYSNAME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Result TABLE (
        CheckName NVARCHAR(100),
        Status NVARCHAR(20),
        Details NVARCHAR(MAX)
    );

    IF @DBName IS NULL
        SET @DBName = DB_NAME();

    -- 1. Last Full Backup
    INSERT INTO @Result
    SELECT 'Recent Full Backup Check',
           CASE WHEN MAX(backup_finish_date) >= DATEADD(HOUR, -2, GETDATE()) THEN 'PASS' ELSE 'FAIL' END,
           'Last Full Backup: ' + COALESCE(CONVERT(VARCHAR, MAX(backup_finish_date), 120), 'None')
    FROM msdb.dbo.backupset
    WHERE database_name = @DBName AND type = 'D';

    -- 2. MDF, LDF, NDF Drive Space
    DECLARE @MDFDrive CHAR(1), @LDFDrive CHAR(1), @NDFDrive CHAR(1);
    SELECT @MDFDrive = LEFT(physical_name, 1) FROM sys.master_files WHERE database_id = DB_ID(@DBName) AND type_desc = 'ROWS' AND file_id = 1;
    SELECT @LDFDrive = LEFT(physical_name, 1) FROM sys.master_files WHERE database_id = DB_ID(@DBName) AND type_desc = 'LOG';
    SELECT TOP 1 @NDFDrive = LEFT(physical_name, 1)
    FROM sys.master_files WHERE database_id = DB_ID(@DBName) AND type_desc = 'ROWS' AND file_id > 1;

    DECLARE @Drives TABLE (Drive CHAR(1), FreeSpaceMB BIGINT);
    INSERT INTO @Drives EXEC xp_fixeddrives;

    DECLARE @MDFFree BIGINT = (SELECT FreeSpaceMB FROM @Drives WHERE Drive = @MDFDrive);
    DECLARE @LDFFree BIGINT = (SELECT FreeSpaceMB FROM @Drives WHERE Drive = @LDFDrive);
    DECLARE @NDFFree BIGINT = (SELECT FreeSpaceMB FROM @Drives WHERE Drive = @NDFDrive);

    INSERT INTO @Result
    VALUES ('MDF Drive Space', IIF(@MDFFree >= 30 * 1024, 'PASS', 'FAIL'), CAST(@MDFFree AS VARCHAR) + ' MB Free'),
           ('LDF Drive Space', IIF(@LDFFree >= 30 * 1024, 'PASS', 'FAIL'), CAST(@LDFFree AS VARCHAR) + ' MB Free'),
           ('NDF Drive Space', IIF(@NDFFree >= 30 * 1024, 'PASS', 'FAIL'), CAST(@NDFFree AS VARCHAR) + ' MB Free');

    -- 3. Secondary Filegroup Check
    INSERT INTO @Result
    SELECT 'Secondary Filegroup Check',
           CASE WHEN EXISTS (SELECT 1 FROM sys.filegroups WHERE type_desc = 'ROWS_FILEGROUP' AND name NOT IN ('PRIMARY')) THEN 'PASS' ELSE 'FAIL' END,
           COALESCE(STUFF((SELECT ', ' + name FROM sys.filegroups WHERE type_desc = 'ROWS_FILEGROUP' AND name NOT IN ('PRIMARY') FOR XML PATH('')), 1, 2, ''), 'No secondary filegroups found');

    -- 4. Year-wise Filegroup Check (DBName_YYYY)
    DECLARE @YearwiseFGStatus NVARCHAR(10) = 'PASS';
    DECLARE @FGDetails NVARCHAR(MAX) = '';
    DECLARE @ThisYear INT = YEAR(GETDATE()), @Y INT = 2020;
    WHILE @Y <= @ThisYear
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @DBName + '_' + CAST(@Y AS VARCHAR))
        BEGIN
            SET @YearwiseFGStatus = 'FAIL';
            SET @FGDetails += @DBName + '_' + CAST(@Y AS VARCHAR) + ' missing; ';
        END
        SET @Y += 1;
    END
    IF @FGDetails = '' SET @FGDetails = 'All year-wise filegroups present';

    INSERT INTO @Result
    SELECT 'Year-wise Filegroups Check', @YearwiseFGStatus, @FGDetails;

    -- 6. Recovery Mode and Log Growth
    DECLARE @RecoveryModel NVARCHAR(20);
    SELECT @RecoveryModel = recovery_model_desc FROM sys.databases WHERE name = @DBName;
    INSERT INTO @Result
    SELECT 'Recovery Model', @RecoveryModel, 'Recovery Model is ' + @RecoveryModel;

    -- 7. Maintenance Window Check
    DECLARE @Now DATETIME = GETDATE();
    DECLARE @DayName VARCHAR(10) = DATENAME(WEEKDAY, @Now);
    DECLARE @TimeOnly TIME = CONVERT(TIME, @Now);

    DECLARE @InWindow BIT = 0;
    IF (
        (@DayName IN ('Monday','Tuesday','Wednesday','Thursday','Friday') AND @TimeOnly BETWEEN '00:30' AND '04:30')
        OR
        (@DayName = 'Saturday' AND @TimeOnly >= '21:00')
        OR
        (@DayName = 'Sunday')
        OR
        (@DayName = 'Monday' AND @TimeOnly <= '04:30')
    )
        SET @InWindow = 1;

    INSERT INTO @Result
    SELECT 'Maintenance Window', IIF(@InWindow = 1, 'YES', 'NO'), 'Current time is ' + CONVERT(VARCHAR, @Now, 120);

    -- 8. Shrink Feasibility
    INSERT INTO @Result
    SELECT 'Shrink Feasibility',
           CASE WHEN SUM(size) - SUM(FILEPROPERTY(name, 'SpaceUsed')) > 0 THEN 'YES' ELSE 'NO' END,
           'Shrinkable Space: ' + CAST(SUM(size - FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 AS VARCHAR) + ' MB'
    FROM sys.database_files WHERE type_desc = 'ROWS';

    -- 9. Disk Redline (any drive below 10%)
    DECLARE @DiskDetails NVARCHAR(MAX) = '', @Drive CHAR(1), @Free BIGINT;
    DECLARE cur CURSOR FOR SELECT Drive, FreeSpaceMB FROM @Drives;
    OPEN cur;
    FETCH NEXT FROM cur INTO @Drive, @Free;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DiskDetails += @Drive + ': ' + CAST(@Free AS VARCHAR) + ' MB Free, ';
        FETCH NEXT FROM cur INTO @Drive, @Free;
    END
    CLOSE cur;
    DEALLOCATE cur;

    INSERT INTO @Result
    SELECT 'Disk Redline Check',
           CASE WHEN EXISTS (SELECT 1 FROM @Drives WHERE FreeSpaceMB < 10240) THEN 'FAIL' ELSE 'PASS' END,
           LEFT(@DiskDetails, LEN(@DiskDetails)-1);

    -- 10. SQL Agent Status
    DECLARE @SQLAgentStatus TABLE (output NVARCHAR(1000));
    INSERT INTO @SQLAgentStatus
    EXEC master.dbo.xp_servicecontrol 'QUERYSTATE', 'SQLServerAgent';

    DECLARE @AgentStatus VARCHAR(1000);
    SELECT TOP 1 @AgentStatus = output FROM @SQLAgentStatus;

    INSERT INTO @Result
    SELECT 'SQL Agent Running',
           CASE WHEN @AgentStatus LIKE '%running%' THEN 'FAIL' ELSE 'PASS' END,
           @AgentStatus;

    -- 11. TempDB Space
    INSERT INTO @Result
    SELECT 'TempDB Free Space',
           CASE WHEN SUM(unallocated_extent_page_count) * 8 / 1024.0 > 100 THEN 'PASS' ELSE 'FAIL' END,
           'TempDB Free Space: ' + CAST(SUM(unallocated_extent_page_count) * 8 / 1024.0 AS VARCHAR) + ' MB'
    FROM tempdb.sys.dm_db_file_space_usage;

    -- 12. Table Info (row count and size)
    IF @TargetTable IS NOT NULL
    BEGIN
        DECLARE @RowCount BIGINT, @TableSizeMB FLOAT;
        SELECT @RowCount = SUM(p.rows)
        FROM sys.tables t
        JOIN sys.partitions p ON t.object_id = p.object_id
        WHERE t.name = @TargetTable AND p.index_id IN (0,1);

        SELECT @TableSizeMB = SUM(reserved_page_count) * 8 / 1024.0
        FROM sys.dm_db_partition_stats
        WHERE object_id = OBJECT_ID(@TargetTable);

        INSERT INTO @Result
        SELECT 'Target Table Info',
               'INFO',
               'Rows: ' + CAST(@RowCount AS VARCHAR) + ', Approx Size: ' + FORMAT(@TableSizeMB, '0.00') + ' MB';

        -- 13. Index Fragmentation
        INSERT INTO @Result
        SELECT 'Index Fragmentation Check',
               CASE WHEN MAX(avg_fragmentation_in_percent) > 30 THEN 'WARN' ELSE 'PASS' END,
               'Max Fragmentation: ' + FORMAT(MAX(avg_fragmentation_in_percent), '0.0') + '%'
        FROM sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@TargetTable), NULL, NULL, 'LIMITED');

        -- 14. Existing Partition
        INSERT INTO @Result
        SELECT 'Table Already Partitioned',
               CASE WHEN ps.name IS NOT NULL THEN 'YES' ELSE 'NO' END,
               ISNULL('Partition Scheme: ' + ps.name + ', Function: ' + pf.name, 'Not partitioned')
        FROM sys.indexes i
        LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
        LEFT JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
        WHERE i.object_id = OBJECT_ID(@TargetTable) AND i.index_id < 2;
    END

    -- Final Output
    SELECT * FROM @Result ORDER BY CheckName;
END

Go