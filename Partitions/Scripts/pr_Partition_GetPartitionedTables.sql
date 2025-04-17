/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/01/11  AY      Initial Revision (JLFL-1181)
------------------------------------------------------------------------------*/

Go

if object_Id('dbo.pr_Partition_GetPartitionedTables') is not null
  drop procedure pr_Partition_GetPartitionedTables;
Go
/*------------------------------------------------------------------------------
  pr_Partition_GetPartitionedTables: Shows the partitioned indices of a Table for the
    given index or all indices.
------------------------------------------------------------------------------*/
create procedure pr_Partition_GetPartitionedTables
as
  declare @vObjectId  TInteger;
begin
  set nocount on;

  /* Show the list of tables which have more than 1 partition */
  select distinct object_name(object_Id) from sys.partitions where partition_number > 1
  order by 1;

end /* pr_Partition_GetPartitionedTables */

Go
