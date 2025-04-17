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
  (@PartitionFunctionName sysname,
   @TargetRangeValue datetime,
   @PartitionIncrementExpression nvarchar(MAX),
   @PartitionRangeInterval datetime,
   @DebugOnly bit = 0)
   
   
AS
  /* Validate partition function exists and get its configuration */
  Declare @BoundaryType nvarchar(20),
          @FunctionID int;
          
begin
  SET NOCOUNT ON;

  select @FunctionID = pf.function_id,
         @BoundaryType = case pf.boundary_value_on_right 
                           when 1 then 'RANGE RIGHT' 
                           else 'RANGE LEFT' 
                         end
  from sys.partition_functions pf
  where pf.name = @PartitionFunctionName;

  if @FunctionID is null
    begin
      RAISERROR('Partition function "%s" does not exist.', 16, 1, @PartitionFunctionName);
      return;
    end;

  /* Get current database name */
  declare @DbName sysname = DB_NAME();

  /* Determine target year and end date */
  declare @TargetYear int = Year(@TargetRangeValue);
  declare @EndDate datetime = DATEFROMPARTS(@TargetYear, 12, 31);

  /* Find last existing boundary and boundary type */
  declare @LastBoundary datetime;
  select top 1 @LastBoundary = cast(value as datetime)
  from sys.partition_range_values
  where function_id = @FunctionID
  order by boundary_id desc;

  /* Determine start date based on boundary type */
  declare @CurrentDate datetime;
    
  if @LastBoundary is null
    begin
      set @CurrentDate = DATEFROMPARTS(@TargetYear, 1, 1);
    end
  else
    begin
      declare @DynSql nvarchar(MAX) = replace(@PartitionIncrementExpression, '@CurrentRangeValue', '@LastBoundaryParam');
      set @DynSql = N'SET @NextDate = ' + @DynSql + N';';
        
      declare @NextDate datetime;
      exec sp_executesql @DynSql, 
           N'@LastBoundaryParam datetime, @NextDate datetime OUTPUT', 
           @LastBoundaryParam = @LastBoundary, 
           @NextDate = @NextDate OUTPUT;

      set @CurrentDate = @NextDate;
    end;

  /* Validate date range */
  if Year(@CurrentDate) > @TargetYear or @CurrentDate > @EndDate
    begin
      RAISERROR('No new partitions needed within target year.', 16, 1);
      return;
    end;

  /* Generate partition dates */
  Create Table #Dates (DateValue datetime);
    
  while @CurrentDate <= @EndDate
    begin
      insert into #Dates (DateValue) VALUES (@CurrentDate);

      declare @DynSql2 nvarchar(MAX) = replace(@PartitionIncrementExpression, '@CurrentRangeValue', '@CurrentDateParam');
      set @DynSql2 = N'SET @NextDate = ' + @DynSql2 + N';';
        
      declare @NextDate2 datetime;
      exec sp_executesql @DynSql2, 
            N'@CurrentDateParam datetime, @NextDate datetime OUTPUT', 
            @CurrentDateParam = @CurrentDate, 
            @NextDate = @NextDate2 OUTPUT;

      if @NextDate2 is null or @NextDate2 > @EndDate
      BREAK;

      set @CurrentDate = @NextDate2;
    end;

  /* Retrieve associated partition schemes */
  select s.name as PartitionSchemeName
  into #Schemes
  from sys.partition_schemes s
  where s.function_id = @FunctionID;

  /* Prepare variables for generating SQL */
  declare @Sql nvarchar(max) = N'';
  declare @DateValue datetime;
  declare @DateStr nvarchar(30);
  declare @SchemeName sysname;
  declare @FilegroupName sysname;

  /* Cursor to iterate through dates */
  declare date_cursor cursor for
  select DateValue
  from #Dates
  order by DateValue;

  OPEN date_cursor;
  FETCH NEXT from date_cursor into @DateValue;

  while @@FETCH_STATUS = 0
    begin
      set @DateStr = convert(nvarchar(30), @DateValue, 23);
      /* MERGE RANGE statement (only if boundary exists) */
      set @Sql += N'-- MERGE existing boundary if necessary IF EXISTS (
                    select 1 from sys.partition_range_values prv
                    where prv.function_id = ' + cast(@FunctionID as nvarchar(10)) + N' AND prv.value = ''' + @DateStr + ''')
                    begin
                      Alter PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName) + N'() MERGE RANGE (''' + @DateStr + N''');
                    end;';

      /* Process each partition scheme */
      Declare scheme_cursor cursor for
      select PartitionSchemeName
      from #Schemes;

      OPEN scheme_cursor;
      FETCH NEXT from scheme_cursor into @SchemeName;

      while @@FETCH_STATUS = 0
        begin
          /* Determine filegroup with fallback logic */
          if @SchemeName like '%!_AnnualDB' ESCAPE '!'
            begin
              declare @YearPart int = YEAR(@DateValue);
              declare @AnnualFgName sysname = @DbName + '_' + cast(@YearPart as nvarchar(4));
                
              if exists (select 1 from sys.filegroups where name = @AnnualFgName)
                set @FilegroupName = QUOTENAME(@AnnualFgName);
              else
                set @FilegroupName = N'[PRIMARY]';
            end
          else if @SchemeName like '%!_Primary' ESCAPE '!'
            set @FilegroupName = N'[PRIMARY]';
          else if @SchemeName like '%!_Secondary' ESCAPE '!'
            set @FilegroupName = N'[SECONDARY]';
          else
            set @FilegroupName = N'[PRIMARY]';
            /* ALTER SCHEME NEXT USED statement */
            SET @Sql += N'ALTER PARTITION SCHEME ' + QUOTENAME(@SchemeName) + N' NEXT USED ' + @FilegroupName + N';
            ';

            FETCH NEXT from scheme_cursor into @SchemeName;
        end;

        CLOSE scheme_cursor;
        DEALLOCATE scheme_cursor;

        -- SPLIT RANGE statement
        set @Sql += N'ALTER PARTITION FUNCTION ' + QUOTENAME(@PartitionFunctionName) + N'() SPLIT RANGE (''' + @DateStr + N''');
';

        FETCH NEXT FROM date_cursor INTO @DateValue;
    end;

    CLOSE date_cursor;
    DEALLOCATE date_cursor;

    -- Add boundary type information to output
    set @Sql = N'-- Partition Function: ' + @PartitionFunctionName + CHAR(13) + CHAR(10) +
               N'-- Boundary Type: ' + @BoundaryType + CHAR(13) + CHAR(10) + 
               @Sql;

    -- Execute or print the generated SQL
    if @DebugOnly = 1
        PRINT @Sql;
    else
        EXEC sp_executesql @Sql;

    -- Cleanup
    Drop Table #Dates;
    Drop Table #Schemes;
end;

GO
