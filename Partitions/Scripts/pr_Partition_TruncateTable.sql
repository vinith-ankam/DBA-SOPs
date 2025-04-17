/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_partition_Truncate_table') is not null
  drop Procedure pr_partition_Truncate_table;
Go
/*------------------------------------------------------------------------------
  Usage:
  
   EXEC [dbo].[pr_partition_Truncate_table] 
    @TableName = 'ImportReceiptDetails',        --ActivityLog
    @Unit = 'M', --M-Months , Y- Years
    @RetentionValue = 3 -Retaintion Months
------------------------------------------------------------------------------*/
Create Procedure pr_partition_Truncate_table
  (@TableName       NVarchar(256),
   @Unit            char(1), -- 'M' for months, 'Y' for years
   @RetentionValue  Int)
as
  declare @FullTableName            NVarchar(513),
          @TruncateSQL              NVarchar(max),
          @CurrentDate DATE =       GETDATE(),
          @RetentionDate            DATE,
          @StartingPartition        Int,
          @EndingPartition          Int;
begin
  SET NOCOUNT ON;

  /* Calculate Retention Date */
  set @RetentionDate =
  case
    when @Unit = 'M' then DATEADD(MONTH, -@RetentionValue, DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1))
    when @Unit = 'Y' then DATEADD(YEAR, -@RetentionValue, DATEFROMPARTS(YEAR(@CurrentDate), MONTH(@CurrentDate), 1))
    else null
  end;

  if @RetentionDate is null
    begin
      raiserror('Unsupported unit. Use "M" for months or "Y" for years.', 16, 1);
    return;
    end

  /*Get Full Table Name */
  select @FullTableName = QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@TableName))) + '.' + QUOTENAME(OBJECT_NAME(OBJECT_ID(@TableName)));

  /*Detect start and end partitions to truncate */
  ;with PartitionBoundary as (
  select
         pf.function_id,pf.boundary_value_on_right,
         cast(
         case 
           when SQL_VARIANT_PROPERTY(prv.value, 'BaseType') = 'int' then prv.value
           when SQL_VARIANT_PROPERTY(prv.value, 'BaseType') in ('date', 'datetime') then cast(convert(char(8), convert(DATE, prv.value), 112) as int)
         else null
         end as int
           ) as BoundaryAsInt,
                prv.boundary_id
  from sys.partition_functions pf
    join sys.partition_range_values prv on pf.function_id = prv.function_id
    ),
    PartitionInfo as (
  select p.partition_number,pb.BoundaryAsInt,pb.boundary_value_on_right,pb.boundary_id
  from sys.partitions p
    join sys.indexes i on p.object_id = i.object_id and i.index_id = 1
    join sys.partition_schemes ps on i.data_space_id = ps.data_space_id
    join sys.destination_data_spaces dds on ps.data_space_id = dds.partition_scheme_id and p.partition_number = dds.destination_id
    join sys.partition_functions pf on ps.function_id = pf.function_id
    join PartitionBoundary pb on pf.function_id = pb.function_id
  where p.object_id = OBJECT_ID(@TableName)
    )
  select @StartingPartition = MIN(partition_number),@EndingPartition = MAX(partition_number)
  from PartitionInfo
  where BoundaryAsInt is not null and 
        ((boundary_value_on_right = 0 and partition_number = boundary_id and BoundaryAsInt < cast(convert(char(8), @RetentionDate, 112) as int))
         or (boundary_value_on_right = 1 and partition_number = boundary_id + 1 and BoundaryAsInt < cast(convert(char(8), @RetentionDate, 112) as int)));

  /*Build and execute the TRUNCATE statement */
  /*Build and execute the TRUNCATE statement */
  if @StartingPartition is not null and @EndingPartition is not null
    begin
      set @TruncateSQL = N'TRUNCATE TABLE ' + @FullTableName + 
                         N' WITH (PARTITIONS (' + cast(@StartingPartition as NVARCHAR) + 
                         N' TO ' + cast(@EndingPartition as NVARCHAR) + N'));';

      exec sp_executesql @TruncateSQL;
      --select @TruncateSQL;
    end
  else
    begin
      declare @RetentionDateText VARCHAR(20) = convert(CHAR(10), @RetentionDate, 120);
        raiserror('No partitions to truncate for cutoff date %s.', 10, 1, @RetentionDateText);
    end

end;

GO

