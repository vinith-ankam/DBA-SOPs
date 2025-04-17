IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'CPURAMUsageLog')
BEGIN
    CREATE TABLE dbo.CPURAMUsageLog
    (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        ServerName NVARCHAR(128),
        CheckTime DATETIME,
        CPUUsagePercent INT,
        AvailableMemoryMB INT,
        TotalMemoryMB INT,
        IsThresholdExceeded BIT,
        ThresholdDetails NVARCHAR(255)
    );
END
GO
