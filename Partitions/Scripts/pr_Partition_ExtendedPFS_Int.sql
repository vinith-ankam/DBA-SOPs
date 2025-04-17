/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/
Go

if object_id('dbo.pr_Partition_ExtendedPFS_Int') is not null
  drop Procedure pr_Partition_ExtendedPFS_Int;
Go

 -------------------------------------*/
/* Usage: 
EXEC dbo.pr_Partition_ExtendedPFS_Int
    @PartitionFunctionName = 'pf_Int1M',
    @PartitionRange = 1000000,
    @ExtensionCount = 197
    -------------------------------------*/


CREATE OR ALTER PROCEDURE dbo.pr_Partition_ExtendedPFS_Int
    @PartitionFunctionName sysname,
    @PartitionRange BIGINT,
    @ExtensionCount INT,
    @DebugOnly BIT = 0,
    @Verbose BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate partition function exists
    DECLARE @FunctionID INT, @BoundaryType NVARCHAR(20);
    
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

    -- Get associated partition schemes
    SELECT s.name AS SchemeName, fg.name AS CurrentFilegroup
    INTO #Schemes
    FROM sys.partition_schemes s
    CROSS APPLY (
        SELECT TOP 1 fg.name
        FROM sys.destination_data_spaces dds
        JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
        WHERE dds.partition_scheme_id = s.data_space_id
        ORDER BY dds.destination_id DESC
    ) fg
    WHERE s.function_id = @FunctionID;

    -- Validate schemes found
    IF NOT EXISTS (SELECT 1 FROM #Schemes)
    BEGIN
        RAISERROR('No partition schemes found for function "%s".', 16, 1, @PartitionFunctionName);
        RETURN;
    END;

    -- Get current maximum boundary value
    DECLARE @MaxBoundary BIGINT;
    SELECT TOP 1 @MaxBoundary = CAST(value AS BIGINT)
    FROM sys.partition_range_values
    WHERE function_id = @FunctionID
    ORDER BY boundary_id DESC;

    -- Handle empty partition function case
    IF @MaxBoundary IS NULL
    BEGIN
        RAISERROR('Partition function "%s" has no defined ranges.', 16, 1, @PartitionFunctionName);
        RETURN;
    END;

    -- Generate extension values
    CREATE TABLE #Ranges (RangeValue BIGINT);
    
    DECLARE @Counter INT = 1;
    WHILE @Counter <= @ExtensionCount
    BEGIN
        INSERT INTO #Ranges VALUES (@MaxBoundary + (@PartitionRange * @Counter));
        SET @Counter += 1;
    END;

    -- Prepare dynamic SQL
    DECLARE @SQL NVARCHAR(MAX) = N'';
    DECLARE @CurrentRange BIGINT;

    DECLARE range_cursor CURSOR FOR
    SELECT RangeValue FROM #Ranges ORDER BY RangeValue;

    OPEN range_cursor;
    FETCH NEXT FROM range_cursor INTO @CurrentRange;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Process each partition scheme
        DECLARE @SchemeName sysname, @FilegroupName sysname;
        DECLARE scheme_cursor CURSOR FOR
        SELECT SchemeName, CurrentFilegroup FROM #Schemes;

        OPEN scheme_cursor;
        FETCH NEXT FROM scheme_cursor INTO @SchemeName, @FilegroupName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Add NEXT USED command
            SET @SQL += N'ALTER PARTITION SCHEME ' + QUOTENAME(@SchemeName) 
                      + N' NEXT USED ' + QUOTENAME(@FilegroupName) + N';
';

            IF @Verbose = 1
                SET @SQL += N'PRINT ''Set NEXT USED for ' + @SchemeName 
                          + N' to ' + @FilegroupName + N''';
';

            FETCH NEXT FROM scheme_cursor INTO @SchemeName, @FilegroupName;
        END;

        CLOSE scheme_cursor;
        DEALLOCATE scheme_cursor;

        -- Add SPLIT RANGE command
        SET @SQL += N'ALTER PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName)
                  + N'() SPLIT RANGE (' + CAST(@CurrentRange AS NVARCHAR(20)) + N');
';

        IF @Verbose = 1
            SET @SQL += N'PRINT ''Split range at ' + CAST(@CurrentRange AS NVARCHAR(20)) + N''';
';

        FETCH NEXT FROM range_cursor INTO @CurrentRange;
    END;

    CLOSE range_cursor;
    DEALLOCATE range_cursor;

    -- Add header information
    SET @SQL = N'-- Partition Function: ' + @PartitionFunctionName + CHAR(13) + CHAR(10)
             + N'-- Boundary Type: ' + @BoundaryType + CHAR(13) + CHAR(10)
             + N'-- Extension Count: ' + CAST(@ExtensionCount AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
             + N'-- Range Size: ' + CAST(@PartitionRange AS NVARCHAR(20)) + CHAR(13) + CHAR(10)
             + @SQL;

    -- Execute or output SQL
    IF @DebugOnly = 1 OR @Verbose = 1
        PRINT @SQL;
    
    IF @DebugOnly = 0
        EXEC sp_executesql @SQL;

    -- Cleanup
    DROP TABLE #Schemes;
    DROP TABLE #Ranges;
END;
GO
