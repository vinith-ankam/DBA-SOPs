## CIMSProd Database Partitioning - Standard Operating Procedure (SOP) ✨

## ✅ Pre-Requisite Scripts to Install in DB

Install the following files:

[pr_Partition_CreateFiles.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_CreateFiles.sql)

[pr_Partition_ExtendedPFS_Date.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_ExtendedPFS_Date.sql)

[pr_Partition_ExtendedPFS_Int.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_ExtendedPFS_Int.sql)

[pr_Partition_FGInfo.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_FGInfo.sql)

[pr_Partition_GetDBInfo.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_GetDBInfo.sql)

[pr_Partition_GetDetails.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_GetDetails.sql)

[pr_Partition_PreCheck.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_PreCheck.sql)

[pr_Partition_TruncateTable.sql](https://github.com/vinith-ankam/DBA-SOPs/blob/main/Partitions/Scripts/pr_Partition_TruncateTable.sql)

SQL/Procedures/sp_Partition/pr_Partition_GetIndexInfo.sql
SQL/Procedures/sp_Partition/pr_Partition_GetPartitionedIndices.sql
SQL/Procedures/sp_Partition/pr_Partition_GetPartitionedTables.sql
SQL/Procedures/sp_Partition/pr_Partition_GetTableInfo.sql
SQL/Functions/pfn_Partitions/pfs_Date.sql
SQL/Functions/pfn_Partitions/pfs_Int.sql

⚠️ Step 1: Run Partition Pre-Check
```sql
Run the below command to verify readiness:

EXEC pr_Partition_PreCheck @DBName='JLCA_CIMSProd';
EXEC pr_Partition_PreCheck @DBName='JLCA_CIMSProd', @TargetTable='ActivityLog';
```
Checks Performed:

📀 Disk Redline Check

🔹 LDF Drive Space

🔹 MDF / NDF Drive Space

⏳ Maintenance Window

🔒 Recovery Model

📆 Recent Full Backup (<2 hours)

💾 Secondary Filegroup Check

🔢 SQL Agent Running

🏛 TempDB Free Space

❄️ Shrink Feasibility

📂 Step 2: Create Secondary Filegroup (if not exists)
```sql
EXEC pr_Partition_CreateFiles @CreateOnlySecondaryFile = 1;
-- or with specific path:
EXEC pr_Partition_CreateFiles @CreateOnlySecondaryFile = 1, @SecondaryFilePath = 'S:\\Temp\\!!POC_Data_Table_Partition\\DATA';
```
📃 Step 3: Verify Filegroup Creation
```sql
EXEC pr_Partition_FGInfo;
```
🔎 Step 4: Check Installed Partition Functions and Schemes
```sql
EXEC pr_Partition_GetDetails;
```
If functions/schemes are missing → proceed to next step.

📄 Step 5: Create Partition Functions and Schemes (if not found)
```sql
-- Run the following SQL files:
SQL/Functions/pfn_Partitions/pfs_Date.sql
SQL/Functions/pfn_Partitions/pfs_Int.sql
```

```sql
-- Re-check
EXEC pr_Partition_GetDetails;
```
⏳ Step 6: Extend Partition Function Boundaries
```sql
--Date-based (Monthly, Quarterly, Yearly)

--Monthly functions:  
     
     --ex:  Using Below Command it will Extend Upto 2026-Dec and each month have a Partition Boundary.
     DECLARE @FutureValue datetime = DATEADD(YEAR, 1, GETDATE());
     DECLARE @PartitionRangeInterval datetime = DATEADD(DAY, 1, 0);

     EXEC pr_Partition_ExtendedPFS_Date
          @PartitionFunctionName = 'pf_DateMonthly',
          @TargetRangeValue = @FutureValue,
          @PartitionIncrementExpression = N'DATEADD(MONTH, 1, CONVERT(datetime, @CurrentRangeValue))',
          @PartitionRangeInterval = @PartitionRangeInterval,
          @DebugOnly = 0;
          
     --Quarterly functions: 
     
     --ex:  Using Below Command it will Extend Upto 2026-Dec and each Quarter have a Partition Boundary.
     DECLARE @FutureValue datetime = DATEADD(YEAR, 1, GETDATE());
     DECLARE @PartitionRangeInterval datetime = DATEADD(DAY, 1, 0);

     EXEC pr_Partition_ExtendedPFS_Date
          @PartitionFunctionName = 'pf_DateQuarterly',
          @TargetRangeValue = @FutureValue,
          @PartitionIncrementExpression = N'DATEADD(MONTH, 3, CONVERT(datetime, @CurrentRangeValue))',
          @PartitionRangeInterval = @PartitionRangeInterval,
          @DebugOnly = 0;
          
     --Yearly functions: 
     
     --ex:  Using Below Command it will Extend Upto 2026-Dec and each Year have a Partition Boundary.
     DECLARE @FutureValue datetime = DATEADD(YEAR, 1, GETDATE());
     DECLARE @PartitionRangeInterval datetime = DATEADD(DAY, 1, 0);

     EXEC pr_Partition_ExtendedPFS_Date
          @PartitionFunctionName = 'pf_DateYearly',
          @TargetRangeValue = @FutureValue,
          @PartitionIncrementExpression = N'DATEADD(YEAR, 1, CONVERT(datetime, @CurrentRangeValue))',
          @PartitionRangeInterval = @PartitionRangeInterval,
          @DebugOnly = 0;
          
     --NOTE: Above commands have only Single Functions, you have to execute as much as needed multiple fuctions , pf_DateTimeMonthly, pf_DateTimeQuarterly...etc..
     
```

Integer-based
```sql
   --Int Functions:
     --pfs_Int1M:  1 Million 
     EXEC dbo.pr_Partition_ExtendedPFS_Int
             @PartitionFunctionName = 'pf_Int1M',
             @PartitionRange = 1000000,
             @ExtensionCount = 197 ; --- Means BufferCount from existing +197
             
     --pfs_Int100K:   1 Lakh
     
     EXEC dbo.pr_Partition_ExtendedPFS_Int
             @PartitionFunctionName = 'pfs_Int100K',
             @PartitionRange = 100000,
             @ExtensionCount = 197 ;
             
     --pfs_Int10K:   10 thoundand
     
     EXEC dbo.pr_Partition_ExtendedPFS_Int
             @PartitionFunctionName = 'pfs_Int10K',
             @PartitionRange = 10000,
             @ExtensionCount = 197 ;
    --NOTE: Above commands have only Single Functions, you have to execute as much as needed multiple fuctions ...Int1K...etc.. 
```

Re-check:
```sql
EXEC pr_Partition_GetDetails;
```
🌐 Step 7: Validate Partition Info (Optional)
```sql
-- DB Level View:
EXEC pr_Partition_GetDBInfo @DatabaseName = 'CIMSProd';

-- With filters:
EXEC pr_Partition_GetDBInfo
    @DatabaseName = 'CIMSProd',
    @OnlyPartitioned = 1,
    @PartitionFunctionName = 'pf_DateMonthly',
    @FilegroupName = 'SECONDARY';
```
📊 Step 8: Table Partitioning Implementation - AuditEntities Example

Before Partitioning


Before Partitioning Table Defination Script:
```sql
      Create Table AuditEntities (
          AuditDetailId            TRecordId identity (1,1) not null,
          AuditId                  TRecordId,
      
          EntityType               TTypeCode,
          EntityId                 TRecordId,
          EntityKey                TEntity,
      
          EntityDetails            TXML,          /* Future Use */
          BusinessUnit             TBusinessUnit  not null,
      
          constraint pkAuditEntities_AuditDetailId primary key (AuditDetailId)
      );
      
      create index ix_AuditEntity_Id              on AuditEntities (EntityId, EntityType) include (AuditId)
      create index ix_AuditEntity_Key             on AuditEntities (EntityKey, EntityType, BusinessUnit) include (AuditId, EntityDetails);
      create index ix_AuditEntity_AuditIdType     on AuditEntities (AuditId, EntityType);
      
      Go
```   
After Partitioning Table Defination Script: 
```sql  
    Create Table AuditEntities (
            AuditDetailId            TRecordId identity (1,1) not null,
            AuditId                  TRecordId not null,
        
            EntityType               TTypeCode,
            EntityId                 TRecordId,
            EntityKey                TEntity,
        
            EntityDetails            TXML,          /* Future Use */
            BusinessUnit             TBusinessUnit  not null,
        
            constraint pkAuditEntities_AuditDetailId primary key clustered (AuditId, AuditDetailId) on ps_Int1M_Secondary (AuditId)
        );
        
        create index ix_AuditEntity_Id              on AuditEntities (EntityId, EntityType) include (AuditId) on ps_Int1M_Secondary(EntityId);
        create index ix_AuditEntity_Key             on AuditEntities (EntityKey, EntityType, BusinessUnit) include (AuditId, EntityDetails) on ps_Int1M_Secondary (AuditId);
        create index ix_AuditEntity_AuditIdType     on AuditEntities (AuditId, EntityType) on ps_Int1M_Secondary (AuditId);
        
        Go 
```

```sql
-- Step i: Drop existing indexes
     drop index ix_AuditEntity_Id              on AuditEntities
     drop index ix_AuditEntity_Key             on AuditEntities
     drop index ix_AuditEntity_AuditIdType     on AuditEntities

-- Step ii: Drop PK
     alter table AuditEntities drop constraint pkAuditEntities_AuditDetailId;

-- Step iii: Alter column to NOT NULL
     alter table AuditEntities alter column AuditId TRecordId not null;

-- Step iv: Create new PK on partition scheme
     alter table AuditEntities add  constraint pkAuditEntities_AuditDetailId primary key clustered (AuditId, AuditDetailId) on ps_Int1M_Secondary (AuditId)

-- Step v: Recreate Indexes
     create index ix_AuditEntity_Id              on AuditEntities (EntityId, EntityType) include (AuditId) on ps_Int1M_Secondary(EntityId);
     create index ix_AuditEntity_Key             on AuditEntities (EntityKey, EntityType, BusinessUnit) include (AuditId, EntityDetails) on ps_Int1M_Secondary (AuditId);
     create index ix_AuditEntity_AuditIdType     on AuditEntities (AuditId, EntityType) on ps_Int1M_Secondary (AuditId);
```

🔢 Step 9: Verify Partitioning Completed Successfully
```sql
EXEC pr_Partition_GetTableInfo @TableName = 'AuditEntities';
-- Optional: @IncludeEmptyPartitions = 'Yes'
```

❗ Important Notes

⚡ Table Partitioning requires clustered index or PK clustered

✔ Computed columns used for partitioning must be persisted

⛔ Columns included in PK must be NOT NULL

🛠 Unique key tables need special handling if partition key not part of key

📊 Always ensure disk space is available for operations

❌ Improper partitioning can lead to DB corruption, log/TempDB issues

🚀 Ready for Deployment!

Make sure to:

Capture screenshots for validation steps

Document table state before and after partitioning

Maintain rollback plan during deployment window

✨ Happy Partitioning! ✨
