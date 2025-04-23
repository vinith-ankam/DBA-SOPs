---
Title: "CIMSDE Database Partitioning"
Author: VIA
Date: 17/04/2025
Topic: Partition
---
## CIMSDE Database Partitioning - Standard Operating Procedure (SOP) ✨


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

{Only above Highlighted links are need to check-in source code} 

`SQL/Procedures/sp_Partition/pr_Partition_GetIndexInfo.sql`

`SQL/Procedures/sp_Partition/pr_Partition_GetPartitionedIndices.sql`

`SQL/Procedures/sp_Partition/pr_Partition_GetPartitionedTables.sql`

`SQL/Procedures/sp_Partition/pr_Partition_GetTableInfo.sql`

`SQL/Functions/pfn_Partitions/pfs_Date.sql`

`SQL/Functions/pfn_Partitions/pfs_Int.sql`

#### ⚠️ Step 1: Run Partition Pre-Check
```sql
Run the below command to verify readiness:

EXEC pr_Partition_PreCheck @DBName='CIMSDE';
EXEC pr_Partition_PreCheck @DBName='CIMSDE', @TargetTable='ImportReceiptHeaders';
```
Checks Performed:

![image](https://github.com/user-attachments/assets/39bb917c-af76-4277-a43e-dc7b968aa0ba)

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
exec pr_Partition_CreateFiles @StartYear= 2021 , @EndYear= 2025
-- or with specific path:
exec pr_Partition_CreateFiles @StartYear = 2021, @EndYear = 2025, 
     @YearWiseLocation = 'E:\SQLData\PartitionFiles\';

```
![image](https://github.com/user-attachments/assets/b95891dc-7a31-406d-9a1c-63c9adb7490c)

#### 📃 Step 3: Verify Filegroup Creation
```sql
EXEC pr_Partition_FGInfo;
```
![image](https://github.com/user-attachments/assets/529e1c50-cf34-452c-ad5a-5222fc2d33c9)

#### 🔎 Step 4: Check Installed Partition Functions and Schemes
```sql
EXEC pr_Partition_GetDetails;
```
![image](https://github.com/user-attachments/assets/c45aae80-2780-4dff-9112-717f800c3090)

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
![image](https://github.com/user-attachments/assets/4b90e288-edb2-4006-b5d6-83d592692af9)

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
             @PartitionFunctionName = 'pf_Int100K',
             @PartitionRange = 100000,
             @ExtensionCount = 197 ;
             
     --pfs_Int10K:   10 thoundand
     
     EXEC dbo.pr_Partition_ExtendedPFS_Int
             @PartitionFunctionName = 'pf_Int10K',
             @PartitionRange = 10000,
             @ExtensionCount = 197 ;
    --NOTE: Above commands have only Single Functions, you have to execute as much as needed multiple fuctions ...Int1K...etc.. 
```
![image](https://github.com/user-attachments/assets/3e3f5e81-5f81-421e-a911-e54efd08f997)

Re-check:
```sql
EXEC pr_Partition_GetDetails;
```
![image](https://github.com/user-attachments/assets/48ac76f8-e35d-42d5-b32d-6c600be0df20)

#### 🌐 Step 7: Validate Partition Info (Optional)
```sql
-- DB Level View:
EXEC pr_Partition_GetDBInfo @DatabaseName = 'CIMSDE';

-- With filters:
EXEC pr_Partition_GetDBInfo
    @DatabaseName = 'CIMSDE',
    @OnlyPartitioned = 1,
    @PartitionFunctionName = 'pf_DateMonthly',
    @FilegroupName = 'SECONDARY';
```
![image](https://github.com/user-attachments/assets/0c3cec5c-50f9-453f-87ad-c8515ff63534)

#### 📊 Step 8: Table Partitioning Implementation - ImportReceiptHeaders Example

Before Partitioning

Before Partitioning Table Defination Script:
```sql
/*------------------------------------------------------------------------------
 Table: ImportReceiptHeaders
------------------------------------------------------------------------------*/
declare @ttImportReceiptHeaders TReceiptHeaderImportType;

select * into ImportReceiptHeaders
from @ttImportReceiptHeaders;

Go

alter table ImportReceiptHeaders drop column RecordId;
alter table ImportReceiptHeaders drop column InputXML;
alter table ImportReceiptHeaders drop column ResultXML;

alter table ImportReceiptHeaders add RecordId        TRecordId identity (1,1),
                                     ExchangeStatus  TStatus,
                                     ImportBatch     TBatch,
                                     InsertedTime    TDateTime default getdate(),
                                     ProcessedTime   TDateTime,
                                     Reference       TDescription,
                                     Result          TVarchar;

create index ix_ImportReceiptHeaders_ExchangeStatus   on ImportReceiptHeaders (ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime);
create index ix_ImportReceiptHeaders_KeyField         on ImportReceiptHeaders (ReceiptNumber, ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime);
create index ix_ImportReceiptHeaders_ImportBatch      on ImportReceiptHeaders (ImportBatch) include (RecordId, ExchangeStatus);
```   
After Partitioning Table Defination Script: 
```sql  
declare @ttImportReceiptHeaders TReceiptHeaderImportType;

select * into ImportReceiptHeaders
from @ttImportReceiptHeaders;

Go

alter table ImportReceiptHeaders drop column RecordId;
alter table ImportReceiptHeaders drop column InputXML;
alter table ImportReceiptHeaders drop column ResultXML;

alter table ImportReceiptHeaders add RecordId        TRecordId identity (1,1),
                                     ExchangeStatus  TStatus,
                                     ImportBatch     TBatch,
                                     InsertedTime    TDateTime default getdate(),
                                     ProcessedTime   TDateTime,
                                     Reference       TDescription,
                                     Result          TVarchar;


/********************************************************************************/
/* Partition the table and indices by InsertedTime using DateTimeMonthly function
   with each month saved into the corresponding years' DB */
/********************************************************************************/

/* Create the clustered index on the partition scheme */
create clustered index ix_ImportReceiptHeaders_Partitioned on dbo.ImportReceiptHeaders(InsertedTime)  
                                                           on ps_DateTimeMonthly_AnnualDB(InsertedTime);  --Partition_SCHEME_Name(Partitioning_Column_Name)

Go

/* Create the non-clustered index on the partition scheme */
create index ix_ImportReceiptHeaders_ExchangeStatus   on ImportReceiptHeaders (ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime)
                                                      on ps_DateTimeMonthly_AnnualDB(InsertedTime);
create index ix_ImportReceiptHeaders_KeyField         on ImportReceiptHeaders (ReceiptNumber, ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime)
                                                      on ps_DateTimeMonthly_AnnualDB(InsertedTime);
create index ix_ImportReceiptHeaders_ImportBatch      on ImportReceiptHeaders (ImportBatch) include (RecordId, ExchangeStatus)
                                                      on ps_DateTimeMonthly_AnnualDB(InsertedTime);
```

```sql
-- Step i: Drop existing indexes
     drop index ix_ImportReceiptHeaders_ExchangeStatus              on ImportReceiptHeaders
     drop index ix_ImportReceiptHeaders_KeyField                    on ImportReceiptHeaders
     drop index ix_ImportReceiptHeaders_ImportBatch                 on ImportReceiptHeaders


-- Step ii: Create new Clustered on partition scheme
     create clustered index ix_ImportReceiptHeaders_Partitioned on dbo.ImportReceiptHeaders(InsertedTime)  
                                                           on ps_DateTimeMonthly_AnnualDB(InsertedTime);

-- Step iii: Recreate Indexes
     create index ix_ImportReceiptHeaders_ExchangeStatus   on ImportReceiptHeaders (ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime)
                                                       on ps_DateTimeMonthly_AnnualDB(InsertedTime);
     create index ix_ImportReceiptHeaders_KeyField         on ImportReceiptHeaders (ReceiptNumber, ExchangeStatus, BusinessUnit) include (RecordId, ProcessedTime)
                                                       on ps_DateTimeMonthly_AnnualDB(InsertedTime);
     create index ix_ImportReceiptHeaders_ImportBatch      on ImportReceiptHeaders (ImportBatch) include (RecordId, ExchangeStatus)
                                                       on ps_DateTimeMonthly_AnnualDB(InsertedTime);
```
![image](https://github.com/user-attachments/assets/4d63a746-e2e3-4888-9e36-4503d303bb73)

#### 🔢 Step 9: Verify Partitioning Completed Successfully
```sql
EXEC pr_Partition_GetTableInfo @TableName = 'ImportReceiptHeaders';
-- Optional: @IncludeEmptyPartitions = 'Yes'
```
![image](https://github.com/user-attachments/assets/71d9214f-0acb-4820-942a-37debe6444ca)

📊 Partitioned Table Summary – CIMSDE Environment
A total of 20 tables have been successfully partitioned across the CIMSDE database, optimized for performance and manageability. The partitioning strategy  date time-based partitioning, mapped to respective year wise filegroups based on data access and growth patterns.

✅ Breakdown of Partitioned Tables

![image](https://github.com/user-attachments/assets/916aa983-caa1-431c-a426-4b79dff4e83b)

### 🧩 Common Partition Keys Used

Date-time : InsertedTime

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
