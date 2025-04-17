/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_CreateFiles') is not null
  drop Procedure pr_Partition_CreateFiles;
Go
/*------------------------------------------------------------------------------
 Default behavior: Creates yearly filegroups from last year to this year
exec pr_Partition_CreateFiles;

create only year wise ndf files:
exec pr_Partition_CreateFiles @StartYear='2021' , @EndYear='2025'

create only a secondary filegroup and file with Default path:
exec pr_Partition_CreateFiles  @CreateOnlySecondaryFile = 1;

create only secondary filegroup/file with specific path (if valid):
exec pr_Partition_CreateFiles @CreateOnlySecondaryFile = 1,
     @SecondaryFilePath = 'W:\Temp\!!POC_Data_Table_Partition\DATA';

------------------------------------------------------------------------------*/
Create Procedure pr_Partition_CreateFiles
  (@StartYear int = null,
   @EndYear int = null,
   @CreateOnlySecondaryFile bit = 0,
   @SecondaryFilePath varchar(500) = null)
as
begin
  SET NOCOUNT ON;

  declare @vStartYear      varchar(4),
          @vEndYear        varchar(4),
          @vYear           varchar(4),
          @vFileGroup      varchar(100),
          @vFileLocation   varchar(500),
          @vFileName       varchar(500),
          @vRecordId       int,
          @vSQL            NVARCHAR(max);
                    
  set @vStartYear = coalesce(@StartYear, year(GETDATE()) - 1);
  set @vEndYear   = coalesce(@EndYear, year(GETDATE()));
  set @vSQL       = '';
  set @vRecordId  = 0;

  /* Get default MDF file location */
  select top 1 @vFileLocation = substring(physical_name, 0, charindex(DB_NAME(), physical_name))
  from sys.database_files
  where type_desc = 'ROWS' and physical_name like '%.mdf';

  /* Handle Custom Secondary File Creation Only */
  if @CreateOnlySecondaryFile = 1
    begin
      /* Override location if a valid custom directory is given */
      if @SecondaryFilePath is not null
        begin
          if RIGHT(@SecondaryFilePath, 1) <> '\' set @SecondaryFilePath += '\';

          declare @DirCheck Table (FileExists int, IsDir int, ParentDirExists int);
          insert into @DirCheck
          exec master.dbo.xp_fileexist @SecondaryFilePath;
             
          if exists (select 1 from @DirCheck where IsDir = 1)
            set @vFileLocation = @SecondaryFilePath;
        end

      set @vFileGroup = 'SECONDARY';
      set @vFileName  = @vFileLocation + DB_NAME() + '_Secondary.ndf';

      /* Add SECONDARY filegroup if not exists */
      if not exists (select 1 from sys.filegroups where name = @vFileGroup)
        begin
          set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';
        end

      /* Add data file if not exists */
      if not exists (select 1 from sys.database_files where name = DB_NAME() + '_Secondary')
        begin
          set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE ( NAME = ''' + DB_NAME() + '_Secondary'',FILENAME = ''' + @vFileName + ''',
                        SIZE = 512MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB ) TO FILEGROUP [' + @vFileGroup + '];';
        end

      exec (@vSQL);
      return;
    end

  /* Proceed with yearly filegroup creation */
  select RecordId, cast(SequenceNo as varchar(4)) as Year
  into #Years
  from dbo.fn_GenerateSequence(@vStartYear, @vEndYear, 0);

  /* Add OLD filegroup and data file if not exists */
  if not exists (select 1 from sys.filegroups where name = DB_NAME() + '_OLD')
    begin
      set @vFileGroup = DB_NAME() + '_OLD';
      set @vFileName = @vFileLocation + @vFileGroup + '.ndf';
      set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';
      set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE (NAME = ''' + @vFileGroup + ''', 
                    FILENAME = ''' + @vFileName + ''', SIZE = 512MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB) TO FILEGROUP [' + @vFileGroup + '];';
    end

  /* Loop through all years */
  while exists (select * from #Years where RecordId > @vRecordId)
    begin
      select top 1  @vRecordId = RecordId,
                    @vYear = Year
      from #Years
      where RecordId > @vRecordId
      order by RecordId;

      set @vFileGroup = DB_NAME() + '_' + @vYear;
      set @vFileName = @vFileLocation + @vFileGroup + '.ndf';

      if exists (select 1 from sys.filegroups where name = @vFileGroup)
            CONTINUE;

        set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';
        set @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE (NAME = ''' + @vFileGroup + ''', FILENAME = ''' + @vFileName + ''', SIZE = 512MB,
                      MAXSIZE = UNLIMITED, FILEGROWTH = 256MB) TO FILEGROUP [' + @vFileGroup + '];';
    end

   exec(@vSQL);
end

GO
