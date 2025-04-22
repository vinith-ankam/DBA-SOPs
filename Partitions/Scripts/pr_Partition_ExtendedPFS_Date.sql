/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_ExtendedPFS_Date') is not null
  drop Procedure pr_Partition_ExtendedPFS_Date;
Go

/*------Usage----------------------
DECLARE @FutureValue datetime = DATEADD(YEAR, 1, GETDATE());
DECLARE @PartitionRangeInterval datetime = DATEADD(DAY, 1, 0);

EXEC pr_Partition_ExtendedPFS_Date
    @PartitionFunctionName = 'pf_DateMonthly',
    @TargetRangeValue = @FutureValue,
    @PartitionIncrementExpression = N'DATEADD(MONTH, 1, CONVERT(datetime, @CurrentRangeValue))',
    @PartitionRangeInterval = @PartitionRangeInterval,
    @DebugOnly = 0;
---------------------------------------*/
create Procedure pr_Partition_ExtendedPFS_Date
    @PartitionFunctionName sysname,
    @TargetRangeValue datetime,
    @PartitionIncrementExpression nvarchar(MAX),
    @PartitionRangeInterval datetime,
    @DebugOnly bit = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate partition function exists and get its configuration
    DECLARE @BoundaryType nvarchar(20);
    DECLARE @FunctionID int;

    SELECT 
        @FunctionID = pf.function_id,
        @BoundaryType = CASE pf.boundary_value_on_right 
                            WHEN 1 THEN 'RANGE RIGHT' 
                            ELSE 'RANGE LEFT' 
                        END
    FROM sys.partition_functions pf
    WHERE pf.name = @PartitionFunctionName;

    IF @FunctionID IS NULL
    BEGIN
        RAISERROR('Partition function "%s" does not exist.', 16, 1, @PartitionFunctionName);
        RETURN;
    END;

    -- Get current database name
    DECLARE @DbName sysname = DB_NAME();

    -- Determine target year and end date
    DECLARE @TargetYear int = YEAR(@TargetRangeValue);
    DECLARE @EndDate datetime = DATEFROMPARTS(@TargetYear, 12, 31);

    -- Find last existing boundary and boundary type
    DECLARE @LastBoundary datetime;
    SELECT TOP 1 @LastBoundary = CAST(value AS datetime)
    FROM sys.partition_range_values
    WHERE function_id = @FunctionID
    ORDER BY boundary_id DESC;

    -- Determine start date based on boundary type
    DECLARE @CurrentDate datetime;
    
    IF @LastBoundary IS NULL
    BEGIN
        SET @CurrentDate = DATEFROMPARTS(@TargetYear, 1, 1);
    END
    ELSE
    BEGIN
        DECLARE @DynSql nvarchar(MAX) = REPLACE(@PartitionIncrementExpression, '@CurrentRangeValue', '@LastBoundaryParam');
        SET @DynSql = N'SET @NextDate = ' + @DynSql + N';';
        
        DECLARE @NextDate datetime;
        EXEC sp_executesql @DynSql, 
            N'@LastBoundaryParam datetime, @NextDate datetime OUTPUT', 
            @LastBoundaryParam = @LastBoundary, 
            @NextDate = @NextDate OUTPUT;

        SET @CurrentDate = @NextDate;
    END;

    -- Validate date range
    IF YEAR(@CurrentDate) > @TargetYear OR @CurrentDate > @EndDate
    BEGIN
        RAISERROR('No new partitions needed within target year.', 16, 1);
        RETURN;
    END;

    -- Generate partition dates
    CREATE TABLE #Dates (DateValue datetime);
    
    WHILE @CurrentDate <= @EndDate
    BEGIN
        INSERT INTO #Dates (DateValue) VALUES (@CurrentDate);

        DECLARE @DynSql2 nvarchar(MAX) = REPLACE(@PartitionIncrementExpression, '@CurrentRangeValue', '@CurrentDateParam');
        SET @DynSql2 = N'SET @NextDate = ' + @DynSql2 + N';';
        
        DECLARE @NextDate2 datetime;
        EXEC sp_executesql @DynSql2, 
            N'@CurrentDateParam datetime, @NextDate datetime OUTPUT', 
            @CurrentDateParam = @CurrentDate, 
            @NextDate = @NextDate2 OUTPUT;

        IF @NextDate2 IS NULL OR @NextDate2 > @EndDate
            BREAK;

        SET @CurrentDate = @NextDate2;
    END;

    -- Retrieve associated partition schemes
    SELECT s.name AS PartitionSchemeName
    INTO #Schemes
    FROM sys.partition_schemes s
    WHERE s.function_id = @FunctionID;

    -- Prepare variables for generating SQL
    DECLARE @Sql nvarchar(MAX) = N'';
    DECLARE @DateValue datetime;
    DECLARE @DateStr nvarchar(30);
    DECLARE @SchemeName sysname;
    DECLARE @FilegroupName sysname;

    -- Cursor to iterate through dates
    DECLARE date_cursor CURSOR FOR
    SELECT DateValue
    FROM #Dates
    ORDER BY DateValue;

    OPEN date_cursor;
    FETCH NEXT FROM date_cursor INTO @DateValue;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @DateStr = CONVERT(nvarchar(30), @DateValue, 23);

        -- MERGE RANGE statement (only if boundary exists)
        SET @Sql += N'-- MERGE existing boundary if necessary
IF EXISTS (
    SELECT 1 
    FROM sys.partition_range_values prv
    WHERE prv.function_id = ' + CAST(@FunctionID AS nvarchar(10)) + N'
    AND prv.value = ''' + @DateStr + '''
)
BEGIN
    ALTER PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName) + N'() MERGE RANGE (''' + @DateStr + N''');
END;
';

        -- Process each partition scheme
        DECLARE scheme_cursor CURSOR FOR
        SELECT PartitionSchemeName
        FROM #Schemes;

        OPEN scheme_cursor;
        FETCH NEXT FROM scheme_cursor INTO @SchemeName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Determine filegroup with fallback logic
            IF @SchemeName LIKE '%!_AnnualDB' ESCAPE '!'
            BEGIN
                DECLARE @YearPart int = YEAR(@DateValue);
                DECLARE @AnnualFgName sysname = @DbName + '_' + CAST(@YearPart AS nvarchar(4));
                
                IF EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @AnnualFgName)
                    SET @FilegroupName = QUOTENAME(@AnnualFgName);
                ELSE
                    SET @FilegroupName = N'[PRIMARY]';
            END
            ELSE IF @SchemeName LIKE '%!_Primary' ESCAPE '!'
                SET @FilegroupName = N'[PRIMARY]';
            ELSE IF @SchemeName LIKE '%!_Secondary' ESCAPE '!'
                SET @FilegroupName = N'[SECONDARY]';
            ELSE
                SET @FilegroupName = N'[PRIMARY]';

            -- ALTER SCHEME NEXT USED statement
            SET @Sql += N'ALTER PARTITION SCHEME ' + QUOTENAME(@SchemeName) + N' NEXT USED ' + @FilegroupName + N';
';

            FETCH NEXT FROM scheme_cursor INTO @SchemeName;
        END;

        CLOSE scheme_cursor;
        DEALLOCATE scheme_cursor;

        -- SPLIT RANGE statement
        SET @Sql += N'ALTER PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName) + N'() SPLIT RANGE (''' + @DateStr + N''');
';

        FETCH NEXT FROM date_cursor INTO @DateValue;
    END;

    CLOSE date_cursor;
    DEALLOCATE date_cursor;

    -- Add boundary type information to output
    SET @Sql = N'-- Partition Function: ' + @PartitionFunctionName + CHAR(13) + CHAR(10) +
               N'-- Boundary Type: ' + @BoundaryType + CHAR(13) + CHAR(10) + 
               @Sql;

    -- Execute or print the generated SQL
    IF @DebugOnly = 1
        PRINT @Sql;
    ELSE
        EXEC sp_executesql @Sql;

    -- Cleanup
    DROP TABLE #Dates;
    DROP TABLE #Schemes;
END;
GO
