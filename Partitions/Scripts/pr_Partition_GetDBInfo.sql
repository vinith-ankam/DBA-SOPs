/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_GetDBInfo') is not null
  drop Procedure pr_Partition_GetDBInfo;
Go
/*------------------------------------------------------------------------------
Usage: If it is Insatlled on Mater Database then we can fetch the details for multiple DB's 
Entire DB:

exec pr_Partition_GetDBInfo @DatabaseName = 'CIMSProd';

Based Upon Filters:

exec pr_Partition_GetDBInfo 
     @DatabaseName = 'CIMSProd',
	   @OnlyPartitioned = 1,
	   @PartitionFunctionName = 'pf_DateMonthly',
     @FilegroupName = 'PRIMARY' --[PRIMARY, SECONDARY, MULTIPLE FILEGROUPS]
------------------------------------------------------------------------------*/
Create Procedure pr_Partition_GetDBInfo
  (@DatabaseName           NVARCHAR(128),
   @TableNames             NVARCHAR(MAX) = null,
   @OnlyPartitioned        BIT = null,
   @FilegroupName          NVARCHAR(128) = null,
   @PartitionSchemeName    NVARCHAR(128) = null,
   @PartitionFunctionName  NVARCHAR(128) = null)
as
begin
  SET NOCOUNT ON;
  
  if DB_ID(@DatabaseName) is null
    begin
      PRINT 'Error: Database not found.';
      return;
    end;

  if object_id('tempdb..#PartitionInfo') is not null drop table #PartitionInfo;
    Create Table  #PartitionInfo (
        SchemaName            NVARCHAR(128),
        TableName             NVARCHAR(512),
        PartitionSchemeName   NVARCHAR(128),
        PartitionFunctionName NVARCHAR(128),
        PartitionKey          NVARCHAR(128),
        Partitioned_Status    NVARCHAR(50),
        FilegroupCount        INT,
        FilegroupName         NVARCHAR(128),
        PartitionCount        INT,
        TableRowCount         BIGINT,
        TableSizeKB           BIGINT,
        TableSizeMB           DECIMAL(18,2),
        TableSizeGB           DECIMAL(18,3),
        TableModifyDateTime   DATETIME,
        SnapshotDateTime      DATETIME
    );

  declare @SQL NVARCHAR(max), @WhereClause NVARCHAR(max) = '';

  if @TableNames is not null
    begin
        Create Table #FilterTables (TableName NVARCHAR(512) primary key);
        insert into #FilterTables (TableName)
        select LTRIM(RTRIM(value)) from STRING_SPLIT(@TableNames, ',');
        set @WhereClause = ' WHERE t.name IN (select TableName from #FilterTables) ';
    end;

    -- Initial table and partition info
  set @SQL = '
  ;WITH TablePartitionInfo as (
  select s.name as SchemaName, t.name as TableName, t.modify_date as TableModifyDateTime, ps.name as PartitionSchemeName, 
         pf.name as PartitionFunctionName, c.name as PartitionKey,
         case 
           when ps.data_space_id is not null then ''Partitioned'' 
         else ''Non-Partitioned'' 
         end as Partitioned_Status,
         fg.name as FilegroupName,
         p.partition_number,
         ps.data_space_id as PS_DataSpaceID,
         i.data_space_id as Index_DataSpaceID
  from ' + QUOTENAME(@DatabaseName) + '.sys.tables t
    inner join ' + QUOTENAME(@DatabaseName) + '.sys.schemas s ON t.schema_id = s.schema_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.indexes i on i.object_id = t.object_id and i.type IN (0,1)
    left join ' + QUOTENAME(@DatabaseName) + '.sys.partition_schemes ps on i.data_space_id = ps.data_space_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.partition_functions pf on ps.function_id = pf.function_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.index_columns ic on ic.object_id = i.object_id and ic.index_id = i.index_id and ic.partition_ordinal = 1
    left join ' + QUOTENAME(@DatabaseName) + '.sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.destination_data_spaces dds on ps.data_space_id = dds.partition_scheme_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.filegroups fg on dds.data_space_id = fg.data_space_id
    left join ' + QUOTENAME(@DatabaseName) + '.sys.partitions p on p.object_id = t.object_id and p.index_id = i.index_id
    ' + @WhereClause + ')
    
  insert into #PartitionInfo (SchemaName, TableName, PartitionSchemeName, PartitionFunctionName, PartitionKey,
                              Partitioned_Status, FilegroupCount, FilegroupName, PartitionCount,
                              TableRowCount, TableSizeKB, TableSizeMB, TableSizeGB, TableModifyDateTime, SnapshotDateTime)
    select SchemaName, TableName, IsNull(MAX(PartitionSchemeName), ''Non-Partitioned''), IsNull(MAX(PartitionFunctionName), ''Non-Partitioned''),
           IsNull(MAX(PartitionKey), ''Non-Partitioned''), max(Partitioned_Status),
           count(DISTINCT FilegroupName),
           case 
             when max(PS_DataSpaceID) is not null and count(distinct FilegroupName) > 1 then ''Partitions are split by multiple filegroups''
             when max(PS_DataSpaceID) is not null then max(FilegroupName)
           else (select top 1 
                        fg2.name 
                 from ' + QUOTENAME(@DatabaseName) + '.sys.filegroups as fg2
                 where fg2.data_space_id = MAX(Index_DataSpaceID))
           end as FilegroupName,
           count(distinct partition_number),
           null, null, null, null,
           max(TableModifyDateTime),
           getdate()
    from TablePartitionInfo
    group by SchemaName, TableName;';

  exec sp_executesql @SQL;

  /* Size update */
  set @SQL = '
  ;with TableStats as (
  select  s.name as SchemaName, t.name as TableName,
          sum(case when ps.index_id IN (0,1) then ps.row_count else 0 end) as TableRowCount,
          sum(ps.reserved_page_count) * 8 as TableSizeKB
  from ' + QUOTENAME(@DatabaseName) + '.sys.tables t
    inner join ' + QUOTENAME(@DatabaseName) + '.sys.schemas s on t.schema_id = s.schema_id
    inner join ' + QUOTENAME(@DatabaseName) + '.sys.dm_db_partition_stats ps on t.object_id = ps.object_id
    ' + @WhereClause + '
  group by s.name, t.name)
  
  update pi
  set TableRowCount = ts.TableRowCount,
      TableSizeKB = ts.TableSizeKB,
      TableSizeMB = CAST(ts.TableSizeKB / 1024.0 AS DECIMAL(18,2)),
      TableSizeGB = CAST(ts.TableSizeKB / 1048576.0 AS DECIMAL(18,3))
  from #PartitionInfo pi
    inner join TableStats ts on pi.SchemaName = ts.SchemaName and
                                pi.TableName = ts.TableName;';

  exec sp_executesql @SQL;

  /* Final filter and output */
  select *
  from #PartitionInfo
  where (@OnlyPartitioned is null or 
        (@OnlyPartitioned = 1 AND Partitioned_Status = 'Partitioned') or 
        (@OnlyPartitioned = 0 AND Partitioned_Status = 'Non-Partitioned')) and
        (@FilegroupName is null or
        FilegroupName = @FilegroupName or
        (@FilegroupName = 'MULTIPLE FILEGROUPS' AND FilegroupName = 'Partitions are split by multiple filegroups')) and
        (@PartitionSchemeName IS NULL OR PartitionSchemeName = @PartitionSchemeName) and 
        (@PartitionFunctionName IS NULL OR PartitionFunctionName = @PartitionFunctionName)
  order by TableRowCount desc;
end

GO
