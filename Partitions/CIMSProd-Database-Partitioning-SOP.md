## CIMSProd Database Partitioning - Standard Operating Procedure (SOP) ✨

#### ✅ Pre-Requisite Scripts to Install in DB

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

#### ⚠️ Step 1: Run Partition Pre-Check
```sql
Run the below command to verify readiness:

EXEC pr_Partition_PreCheck @DBName='JLCA_CIMSProd';
EXEC pr_Partition_PreCheck @DBName='JLCA_CIMSProd', @TargetTable='ActivityLog';
```
Checks Performed:
![image](https://github.com/user-attachments/assets/59e203b0-9ae6-4bb6-89be-e2b0a9727ab2)

#### 📀 Disk Redline Check

🔹 LDF Drive Space

🔹 MDF / NDF Drive Space

⏳ Maintenance Window

🔒 Recovery Model

📆 Recent Full Backup (<2 hours)

💾 Secondary Filegroup Check

🔢 SQL Agent Running

🏛 TempDB Free Space

❄️ Shrink Feasibility

#### 📂 Step 2: Create Secondary Filegroup (if not exists)
```sql
EXEC pr_Partition_CreateFiles @CreateOnlySecondaryFile = 1;
-- or with specific path:
EXEC pr_Partition_CreateFiles @CreateOnlySecondaryFile = 1, @SecondaryFilePath = 'S:\\Temp\\!!POC_Data_Table_Partition\\DATA';

![image](https://github.com/user-attachments/assets/d1efd942-2a7e-4d51-a582-3e9d2353e228)
```
#### 📃 Step 3: Verify Filegroup Creation
```sql
EXEC pr_Partition_FGInfo;
```
![image](https://github.com/user-attachments/assets/2c2ec0b0-641e-4cf3-ae38-ee725eb8da38)

#### 🔎 Step 4: Check Installed Partition Functions and Schemes
```sql
EXEC pr_Partition_GetDetails;
```
![image](https://github.com/user-attachments/assets/c9c12d1d-df92-4796-83e6-6717f0c72ea9)

If functions/schemes are missing → proceed to next step.

#### 📄 Step 5: Create Partition Functions and Schemes (if not found)
```sql
-- Run the following SQL files:
SQL/Functions/pfn_Partitions/pfs_Date.sql
SQL/Functions/pfn_Partitions/pfs_Int.sql
```
![image](https://github.com/user-attachments/assets/c7e9ad91-1d2b-4469-bc76-2bc19586bac1)

```sql
-- Re-check
EXEC pr_Partition_GetDetails;
```
![image](https://github.com/user-attachments/assets/d1448dd6-2374-475d-a15c-2ec347897898)

Boundary Validation whether those Functions are Created or Extended Boundaries as per Current Date means If date and datetime function are in Current +1 Year and Int functions are would be more buffers like 200+...

#### ⏳ Step 6: Extend Partition Function Boundaries
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
![image](https://github.com/user-attachments/assets/e6b55d7d-bf33-441e-8ff8-1307d9a51de4)

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
![image](https://github.com/user-attachments/assets/3e3f5e81-5f81-421e-a911-e54efd08f997)

Re-check:
```sql
EXEC pr_Partition_GetDetails;
```
![image](https://github.com/user-attachments/assets/2fcd2dcf-688d-46a6-92ba-925300997b75)

#### 🌐 Step 7: Validate Partition Info (Optional)
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
![image](https://github.com/user-attachments/assets/0c3cec5c-50f9-453f-87ad-c8515ff63534)

#### 📊 Step 8: Table Partitioning Implementation - AuditEntities Example

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
![image](https://github.com/user-attachments/assets/4d63a746-e2e3-4888-9e36-4503d303bb73)

#### 🔢 Step 9: Verify Partitioning Completed Successfully
```sql
EXEC pr_Partition_GetTableInfo @TableName = 'AuditEntities';
-- Optional: @IncludeEmptyPartitions = 'Yes'
```
![image](https://github.com/user-attachments/assets/15eca68e-25e7-4cfb-a4f9-3081c23c7005)

###  ❗ Important Notes

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
