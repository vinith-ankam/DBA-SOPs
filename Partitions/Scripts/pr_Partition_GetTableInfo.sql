/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/02/17  AY      Made changes to show EmptyPartitions based on the flag (JLCA-19)
  2024/06/12  MS      Initial Revision (HA-4071)
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_GetTableInfo') is not null
  drop Procedure pr_Partition_GetTableInfo;
Go
/*------------------------------------------------------------------------------
  pr_Partition_GetTableInfo: Show the partitions of the given table with the
  range and record count of each partition
------------------------------------------------------------------------------*/
Create Procedure pr_Partition_GetTableInfo
  (@TableName              TVarchar,
   @IncludeEmptyPartitions TString = 'No')
as
  declare @vObjectName TVarChar;
begin
  SET NOCOUNT ON;

  /* Initialize */
  select @vObjectName = db_name() + '.dbo.' + @TableName --('DB_Name.Schema.Table_Name)

  /* script to get partition info */
  select
    object_name(pstats.object_id)         as TableName,
    ps.name                               as PartitionSchemeName,
    pstats.partition_number               as PNumber,
    pstats.row_count                      as PRowCount,
    case
      when pf.boundary_value_on_right = 0
      then c.name + ' > ' + cast(isnull(LAG(prv.value) over(partition by pstats.object_id order by pstats.object_id, pstats.partition_number), 'Infinity') as varchar(100)) + ' and ' + c.name + ' <= ' + cast(isnull(prv.value, 'Infinity') as varchar(100))
      else c.name + ' >= ' + cast(isnull(prv.value, 'Infinity') as varchar(100))  + ' and ' + c.name + ' < ' + cast(isnull(LEAD(prv.value) over(partition by pstats.object_id order by pstats.object_id, pstats.partition_number), 'Infinity') as varchar(100))
    end                                   as PartitionRange,
    c.name                                as PartitionKey,
    ds.name                               as PartitionFilegroupName,
    pf.name                               as PartitionFunctionName,
    case pf.boundary_value_on_right when 0 then 'Range Left' else 'Range Right' end
                                          as PartitionFunctionRange,
    case pf.boundary_value_on_right when 0 then 'Upper Boundary' else 'Lower Boundary' end
                                          as PartitionBoundary,
    prv.value                             as PartitionBoundaryValue,
    p.data_compression_desc               as DataCompression,
    object_schema_name(pstats.object_id)  as SchemaName
  from sys.dm_db_partition_stats as pstats
    inner join sys.partitions as p                on pstats.partition_id = p.partition_id
    inner join sys.destination_data_spaces as dds on pstats.partition_number = dds.destination_id
    inner join sys.data_spaces as ds              on dds.data_space_id = ds.data_space_id
    inner join sys.partition_schemes as ps        on dds.partition_scheme_id = ps.data_space_id
    inner join sys.partition_functions as pf      on ps.function_id = pf.function_id
    inner join sys.indexes as i                   on pstats.object_id = i.object_id and
                                                     pstats.index_id = i.index_id and
                                                     dds.partition_scheme_id = i.data_space_id and
                                                     i.type <= 1 /* Heap or Clustered Index */
    inner join sys.index_columns as ic            on i.index_id = ic.index_id and
                                                     i.object_id = ic.object_id and
                                                     ic.partition_ordinal > 0
    inner join sys.columns as c                   on pstats.object_id = c.object_id and
                                                     ic.column_id = c.column_id
    left join sys.partition_range_values as prv   on pf.function_id = prv.function_id and
                                                     pstats.partition_number = (case pf.boundary_value_on_right when 0 then prv.boundary_id else (prv.boundary_id+1) end)
  where (pstats.object_id = object_id(@vObjectName)) and
        ((@IncludeEmptyPartitions = 'Yes') or (pstats.row_count > 0))
  order by TableName, pstats.Partition_Number;

end /* pr_Partition_GetTableInfo */

Go
