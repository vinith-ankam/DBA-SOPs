/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/01/06  VIA      Initial Revision (JLFL-1181)
------------------------------------------------------------------------------*/

Go

if object_Id('dbo.pr_Partition_GetPartitionedIndices') is not null
  drop procedure pr_Partition_GetPartitionedIndices;
Go
/*------------------------------------------------------------------------------
  pr_Partition_GetPartitionedIndices: Shows the list of paritioned indices
------------------------------------------------------------------------------*/
create procedure pr_Partition_GetPartitionedIndices
  (@TableName  TVarChar,
   @OrderBy    int = null)
as
  declare @vObjectId  TInteger;
begin
  set nocount on;

  /* Get ids */
  select @vObjectId = object_id from sys.tables where (name = @TableName);

  select object_name(p.object_Id) as TableName,
        i.name as IndexName,
        i.type_desc as IndexType,
        p.partition_number PNumber,
        p.rows PRows,
        i.filter_definition IndexFilter
  from sys.partitions P
      inner join sys.indexes I on (p.object_Id = I.object_Id) and
                                  (P.index_Id = I.index_Id)
  where ((@vObjectId is null) or (p.object_id = @vObjectId)) and (p.partition_number > 1)
  order by P.rows desc

end /* pr_Partition_GetPartitionedIndices */

Go
