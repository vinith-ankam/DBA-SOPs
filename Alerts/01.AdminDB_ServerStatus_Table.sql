USE AdminDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ServerStatus')
BEGIN
    CREATE TABLE dbo.ServerStatus
    (
        ServerName NVARCHAR(128) PRIMARY KEY, -- Server name
        IsThresholdExceeded BIT NOT NULL DEFAULT 0, -- 0 = Normal, 1 = Threshold exceeded
        LastCheckTime DATETIME NOT NULL DEFAULT GETDATE() -- Last status check time
    );
END
GO

-- Insert initial record for the server (if not present)
IF NOT EXISTS (SELECT 1 FROM dbo.ServerStatus WHERE ServerName = @@SERVERNAME)
BEGIN
    INSERT INTO dbo.ServerStatus (ServerName, IsThresholdExceeded, LastCheckTime)
    VALUES (@@SERVERNAME, 0, GETDATE());
END
