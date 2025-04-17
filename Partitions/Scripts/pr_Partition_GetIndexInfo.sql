/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/03/05  VIA      Corrected PartitionRange Boundaries Bug (JLCA-56)
  2025/02/17  AY      Made changes to show EmptyPartitions based on the flag (JLCA-19)
  2025/01/06  VIA     Initial Revision (JLFL-1181)
------------------------------------------------------------------------------*/

Go

if object_Id('dbo.pr_Partition_GetIndexInfo') is not null
  drop procedure pr_Partition_GetIndexInfo;
Go
/*------------------------------------------------------------------------------
  pr_Partition_GetIndexInfo: Shows the partitioned indices of a Table for the
    given index or all indices.
------------------------------------------------------------------------------*/
create procedure pr_Partition_GetIndexInfo
  (@TableName              TVarChar,
   @IndexName              TVarChar = null,
   @IncludeEmptyPartitions TString = 'No')
as
  declare @vObjectId  TInteger;
begin
  set nocount on;

  /* Get ids */
  select @vObjectId = object_id from sys.tables where (name = @TableName);

  /* script to get partition with Index info */
  select
      object_name(PST.object_Id)           as TableName,
      I.Name                               as IndexName,
      I.Type_Desc                          as IndexType,
      PS.Name                              as PartitionSchemename,
      PST.partition_number                 as PNumber,
      PST.row_count                        as PRowCount,
      case
          when PF.boundary_value_on_right = 0 
          then C.Name + ' >= ' + isnull(convert(varchar(30), lag(PRV.value) over (partition by PST.object_Id, I.index_id order by PST.partition_number), 107), 'Negative-or-NULL') + ' and ' + C.Name + ' < ' + isnull(convert(varchar(30), PRV.value, 107), 'Infinity')
          else C.Name + ' >= ' + isnull(convert(varchar(30), PRV.value, 107), 'Negative-or-NULL') + ' and ' + C.Name + ' < ' + isnull(convert(varchar(30), lead(PRV.value) over (partition by PST.object_Id, I.index_id order by PST.partition_number), 107), 'Infinity')
      end                                  as PartitionRange,
      I.filter_definition                  as IndexFilter,
      C.Name                               as PartitionKey,
      DS.Name                              as PartitionFilegroupname,
      PF.Name                              as PartitionFunctionname,
      case PF.boundary_value_on_right
          when 0 then 'range left'
          else 'range right'
      end                                  as PartitionFunctionRange,
      case PF.boundary_value_on_right
          when 0 then 'upper boundary'
          else 'lower boundary'
      end                                  as PartitionBoundary,
      PRV.value                            as PartitionBoundaryvalue,
      P.data_compression_desc              as DataCompression,
      object_schema_name(PST.object_Id)    as Schemaname
  from sys.dm_db_partition_stats           PST
    inner join sys.partitions              P   on (PST.partition_Id = P.partition_Id)
    inner join sys.destination_data_spaces DDS on (PST.partition_number = DDS.destination_Id)
    inner join sys.data_spaces             DS  on (DDS.data_space_Id = DS.data_space_Id)
    inner join sys.partition_schemes       PS  on (DDS.partition_scheme_Id = PS.data_space_Id)
    inner join sys.partition_functions     PF  on (PS.function_Id = PF.function_Id)
    inner join sys.indexes                 I   on (PST.object_Id = I.object_Id) and
                                                  (PST.index_Id = I.index_Id) and
                                                  (DDS.partition_scheme_Id = I.data_space_Id) and
                                                  (I.type <= 1 or I.type = 2) -- heap, clustered, or non-clustered index
    inner join sys.index_columns           IC  on (I.index_Id = IC.index_Id) and
                                                  (I.object_Id = IC.object_Id) and
                                                  (IC.partition_ordinal > 0)
    inner join sys.columns                 C   on (PST.object_Id = C.object_Id) and
                                                  (IC.column_Id = C.column_Id)
    left join sys.partition_range_values   PRV on (PF.function_Id = PRV.function_Id) and
                                                  (PST.partition_number = (case PF.boundary_value_on_right when 0 then PRV.boundary_Id else (PRV.boundary_Id + 1) end))
  where (PST.object_Id = @vObjectId) and
        (I.Name = coalesce(@IndexName, I.Name)) and
        ((@IncludeEmptyPartitions = 'Yes') or (PST.row_count > 0))
  order by TableName, I.Name, PST.Partition_Number;

end /* pr_Partition_GetIndexInfo */

Go
