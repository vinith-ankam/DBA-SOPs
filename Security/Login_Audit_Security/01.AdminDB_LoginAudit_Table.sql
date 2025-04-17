USE AdminDB;
GO

CREATE TABLE dbo.LoginAudit (
    EventID INT IDENTITY(1,1) NOT NULL,
    EventType NVARCHAR(50) NULL,
    LoginName NVARCHAR(256) NULL,
    Hostname NVARCHAR(256) NULL,
    IPAddress NVARCHAR(50) NULL,
    Application NVARCHAR(256) NULL,
    SessionID INT NULL,
    EventTime DATETIME NULL,
    PRIMARY KEY CLUSTERED (EventID ASC)
);
GO