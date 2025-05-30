/*------------------------------------------------------------------------------
  Copyright (c) Foxfire Technologies (India) Ltd.  All rights reserved

  Revision History:

  Date        Person  Comments

  2025/04/16  VIA     Initial Revision ()
------------------------------------------------------------------------------*/

Go

if object_id('dbo.pr_Partition_GetDetails') is not null
  drop Procedure pr_Partition_GetDetails;
Go

/*------------------------------------------------------------------------------
Usage : 
List All Patition Functions and Schemes: exec pr_Partition_GetDetails
List Only Specific Patition Functions: exec pr_Partition_GetDetails @PartitionFunctionName ='pf_Int1M'
------------------------------------------------------------------------------*/
Create Procedure dbo.pr_Partition_GetDetails
  (@PartitionFunctionName SYSNAME = NULL)
as
begin
  SET NOCOUNT ON;

  if @PartitionFunctionName is null
  begin
      -- List all partition functions with first/last boundaries
      select 
          DatabaseName        = DB_NAME(),  
          PartitionFunction   = pf.name, 
          PartitionScheme     = ps.name,
          BoundaryType        = case pf.boundary_value_on_right 
                                  when 1 then 'RANGE RIGHT' 
                                  else 'RANGE LEFT' 
                                end,
          TotalPartitions     = pf.fanout + 0,
          FirstBoundaryValue  = convert(nvarchar(100), 
                                  (select top 1 value 
                                   from sys.partition_range_values 
                                   where function_id = pf.function_id 
                                   order by boundary_id)),
          LastBoundaryValue   = convert(nvarchar(100), 
                                  (select top 1 value 
                                   from sys.partition_range_values 
                                   where function_id = pf.function_id 
                                   order by boundary_id desc)),
          CreateDatetime      = pf.create_date,
          ModifyDatetime      = pf.modify_date
      from sys.partition_functions pf
      left join sys.partition_schemes ps 
          on pf.function_id = ps.function_id;
      return;
  end;

  declare 
      @FunctionID          INT,
      @DbName              SYSNAME = DB_NAME(),
      @PartitionSchemeName SYSNAME,
      @BoundaryOnRight     BIT,
      @TotalBoundaries     INT,
      @FirstBoundary       SQL_VARIANT,
      @LastBoundary        SQL_VARIANT,
      @CreateDate          DATETIME,
      @ModifyDate          DATETIME;

  select 
      @FunctionID      = pf.function_id,
      @BoundaryOnRight = pf.boundary_value_on_right,
      @TotalBoundaries = pf.fanout,
      @CreateDate      = pf.create_date,
      @ModifyDate      = pf.modify_date
  from sys.partition_functions pf
  where pf.name = @PartitionFunctionName;

  if @FunctionID is null
  begin
      RAISERROR('Partition function "%s" does not exist.', 16, 1, @PartitionFunctionName);
      return;
  end

  -- Assign Partition Scheme Name
  select top 1 
      @PartitionSchemeName = ps.name
  from sys.partition_schemes ps
  where ps.function_id = @FunctionID;

  -- Boundary values
  select TOP 1 @FirstBoundary = value
  from sys.partition_range_values
  where function_id = @FunctionID
  order by boundary_id;

  select TOP 1 @LastBoundary = value
  from sys.partition_range_values
  where function_id = @FunctionID
  order by boundary_id desc;

  -- Summary for specific function
  select 
      DatabaseName       = @DbName,
      PartitionFunction  = @PartitionFunctionName,
      PartitionScheme    = @PartitionSchemeName,
      BoundaryType       = case @BoundaryOnRight when 1 then 'RANGE RIGHT' else 'RANGE LEFT' end,
      FirstBoundaryValue = convert(NVARCHAR(100), @FirstBoundary),
      LastBoundaryValue  = convert(NVARCHAR(100), @LastBoundary),
      TotalPartitions    = @TotalBoundaries + 0,
      CreateDatetime     = @CreateDate,
      ModifyDatetime     = @ModifyDate;

  -- Detailed Boundaries
  select 
      BoundaryID       = boundary_id,
      BoundaryValue    = convert(NVARCHAR(100), value),
      PartitionNumber  = boundary_id + case @BoundaryOnRight when 1 then 1 else 0 end
  from sys.partition_range_values
  where function_id = @FunctionID
  order by boundary_id;
end
GO

