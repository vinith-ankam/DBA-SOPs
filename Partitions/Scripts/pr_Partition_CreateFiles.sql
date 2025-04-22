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
  
create files in specified location
exec pr_Partition_CreateFiles @StartYear = 2020, @EndYear = 2025, 
     @YearWiseLocation = 'E:\SQLData\PartitionFiles\';


------------------------------------------------------------------------------*/
Create Procedure pr_Partition_CreateFiles
  @StartYear INT = NULL,
  @EndYear INT = NULL,
  @CreateOnlySecondaryFile BIT = 0,
  @SecondaryFilePath VARCHAR(500) = NULL,
  @YearWiseLocation VARCHAR(500) = NULL
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @vStartYear      INT,
          @vEndYear        INT,
          @vYear           INT,
          @vFileGroup      VARCHAR(100),
          @vFileLocation   VARCHAR(500),
          @vYearFilePath   VARCHAR(500),
          @vFileName       VARCHAR(500),
          @vSQL            NVARCHAR(MAX) = '';

  -- Set default values
  SET @vStartYear = ISNULL(@StartYear, YEAR(GETDATE()) - 1);
  SET @vEndYear   = ISNULL(@EndYear, YEAR(GETDATE()));

  -- Get default MDF file location
  SELECT TOP 1 @vFileLocation = SUBSTRING(physical_name, 0, CHARINDEX(DB_NAME(), physical_name))
  FROM sys.database_files
  WHERE type_desc = 'ROWS' AND physical_name LIKE '%.mdf';

  -- If @CreateOnlySecondaryFile = 1, create only the SECONDARY filegroup
  IF @CreateOnlySecondaryFile = 1
  BEGIN
    -- Override location if custom directory is given and exists
    IF @SecondaryFilePath IS NOT NULL
    BEGIN
      IF RIGHT(@SecondaryFilePath, 1) <> '\' SET @SecondaryFilePath += '\';

      DECLARE @DirCheck TABLE (FileExists INT, IsDir INT, ParentDirExists INT);
      INSERT INTO @DirCheck EXEC master.dbo.xp_fileexist @SecondaryFilePath;

      IF EXISTS (SELECT 1 FROM @DirCheck WHERE IsDir = 1)
        SET @vFileLocation = @SecondaryFilePath;
    END

    SET @vFileGroup = 'SECONDARY';
    SET @vFileName  = @vFileLocation + DB_NAME() + '_Secondary.ndf';

    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @vFileGroup)
      SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';

    IF NOT EXISTS (SELECT 1 FROM sys.database_files WHERE name = DB_NAME() + '_Secondary')
      SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE ( NAME = ''' + DB_NAME() + '_Secondary'', FILENAME = ''' + @vFileName + ''', SIZE = 512MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB ) TO FILEGROUP [' + @vFileGroup + '];';

    EXEC (@vSQL);
    RETURN;
  END

  -- Use YearWiseLocation or default location
  SET @vYearFilePath = ISNULL(@YearWiseLocation, @vFileLocation);
  IF RIGHT(@vYearFilePath, 1) <> '\' SET @vYearFilePath += '\';

  -- Add OLD filegroup and data file
  SET @vFileGroup = DB_NAME() + '_OLD';
  SET @vFileName  = @vYearFilePath + @vFileGroup + '.ndf';

  IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @vFileGroup)
  BEGIN
    SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';
    SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE (NAME = ''' + @vFileGroup + ''', FILENAME = ''' + @vFileName + ''', SIZE = 512MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB) TO FILEGROUP [' + @vFileGroup + '];';
  END

  -- Loop through years and add filegroups/files
  WHILE @vStartYear <= @vEndYear
  BEGIN
    SET @vYear = @vStartYear;
    SET @vFileGroup = DB_NAME() + '_' + CAST(@vYear AS VARCHAR(4));
    SET @vFileName  = @vYearFilePath + @vFileGroup + '.ndf';

    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = @vFileGroup)
    BEGIN
      SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILEGROUP [' + @vFileGroup + '];';
      SET @vSQL += 'ALTER DATABASE [' + DB_NAME() + '] ADD FILE (NAME = ''' + @vFileGroup + ''', FILENAME = ''' + @vFileName + ''', SIZE = 512MB, MAXSIZE = UNLIMITED, FILEGROWTH = 256MB) TO FILEGROUP [' + @vFileGroup + '];';
    END

    SET @vStartYear += 1;
  END

  -- Execute all statements at once
  EXEC (@vSQL);
END
GO
