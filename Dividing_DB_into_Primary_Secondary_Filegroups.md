### Proof of Concept: Moving Tables to a Secondary Filegroup in SQL Server

### Prerequisites

1. Adequate disk space for the new filegroup and files.
2. Administrative privileges to modify database structures and perform backups.

### Step-by-Step Implementation

1. **Add a Secondary Filegroup**
2. **Move Tables to the Secondary Filegroup**
3. **Backup Both Filegroups**
4. **Restore Only the Primary Filegroup**

### Step 1: Add a Secondary Filegroup

```sql
USE JLCA_CIMSProd;
GO

-- Add a secondary filegroup
ALTER DATABASE JLCA_CIMSProd
ADD FILEGROUP SecondaryFileGroup;
GO

-- Add a file to the secondary filegroup
ALTER DATABASE JLCA_CIMSProd
ADD FILE (
    NAME = N'JLCA_CIMSProd_Secondary',
    FILENAME = N'C:\\SQLData\\JLCA_CIMSProd_Secondary.ndf', -- Change the path as per your environment
    SIZE = 5MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 5MB
) TO FILEGROUP SecondaryFileGroup;
GO

```

### Step 2: Move Tables to the Secondary Filegroup

For the `ActivityLog` table, we need to manage its clustered indexes to move it to the secondary filegroup. Here's how to handle this table:

```sql
USE JLCA_CIMSProd;
GO

-- Drop existing clustered index
ALTER TABLE dbo.ActivityLog DROP CONSTRAINT pkActivityLog_RecordId;
GO

-- Recreate the clustered index on the secondary filegroup
ALTER TABLE dbo.ActivityLog
ADD CONSTRAINT pkActivityLog_RecordId PRIMARY KEY CLUSTERED (RecordId) ON SecondaryFileGroup;
GO

-- Recreate non-clustered indexes
CREATE NONCLUSTERED INDEX ix_ActivityLog_Operation ON dbo.ActivityLog(Operation) ON SecondaryFileGroup;
GO
CREATE NONCLUSTERED INDEX ix_ActivityLog_ProcName ON dbo.ActivityLog(ProcName) ON SecondaryFileGroup;
GO
CREATE NONCLUSTERED INDEX ix_ActivityLog_ActivityDate ON dbo.ActivityLog(ActivityDate) ON SecondaryFileGroup;
GO
CREATE NONCLUSTERED INDEX ix_ActivityLog_EntityKey ON dbo.ActivityLog(EntityKey) ON SecondaryFileGroup;
GO

```

### Step 3: Backup Both Filegroups

```sql
-- Backup both the primary and secondary filegroups
BACKUP DATABASE JLCA_CIMSProd
	FILEGROUP = 'PRIMARY',
	FILEGROUP = 'SecondaryFileGroup'
	TO DISK = 'C:\\SQLBackups\\JLCA_CIMSProd_Filegroup.bak' WITH INIT;
GO

```

### Step 4: Restore Only the Primary Filegroup

```sql
-- Create a new database on the UAT server
CREATE DATABASE JLCA_CIMSProd_UAT
ON PRIMARY (
    NAME = 'JLCA_CIMSProd_UAT',
    FILENAME = 'C:\\SQLData\\JLCA_CIMSProd_UAT.mdf', -- Change the path as per your environment
    SIZE = 10MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 5MB
);
GO

-- Restore the primary filegroup only
RESTORE DATABASE JLCA_CIMSProd_UAT
FILEGROUP = 'PRIMARY'
FROM DISK = 'C:\\SQLBackups\\JLCA_CIMSProd_Filegroup.bak' -- Change the path as per your environment
WITH PARTIAL, RECOVERY, REPLACE,
MOVE 'JLCA_CIMSProd' TO 'C:\\SQLData\\JLCA_CIMSProd_UAT.mdf';
GO

```

### Pros and Cons

### Pros:

1. **Performance Improvement**: Separating large and frequently accessed tables into a different filegroup can improve performance by reducing contention on the primary filegroup.
2. **Backup Efficiency**: Allows for partial backups, reducing the time and storage required for backing up and restoring only essential parts of the database.
3. **Maintenance**: Simplifies database maintenance tasks by isolating specific tables in a separate filegroup.

### Cons:

1. **Complexity**: Adding and managing multiple filegroups increases the complexity of the database management.
2. **Recovery**: During disaster recovery, all filegroups must be restored to bring the database online completely.
3. **Disk Space Management**: Requires careful planning of disk space allocation and monitoring to ensure no filegroup runs out of space.
