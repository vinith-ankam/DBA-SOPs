/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_FGInfo') is not null
  drop Procedure pr_Partition_FGInfo;
Go


Create Procedure pr_Partition_FGInfo
as
begin
  SET NOCOUNT ON;

  select DB_NAME() as [Database Name], df.name as [DB File Name], fg.name as [File Group Name], df.physical_name as [File Path],
         df.type_desc as [File Type], df.size / 128 as [Current Size (MB)],
         case
           when df.max_size = -1 then 'Unlimited'
         else cast(df.max_size / 128 as varchar(20))
         end as [Max Size (MB)],
         case
           when df.is_percent_growth = 1 then cast(df.growth as varchar(10)) + '%'
            else cast(df.growth / 128 as varchar(10)) + ' MB'
         end as [Auto Growth],
        df.state_desc as [File State],
        df.create_lsn as [Create LSN]
  from sys.database_files as df
    inner join sys.filegroups as fg on df.data_space_id = fg.data_space_id
  order by df.name;
end;
