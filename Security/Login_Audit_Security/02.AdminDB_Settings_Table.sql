USE AdminDB;
GO

CREATE TABLE dbo.Settings (
    AlertEnabled BIT NOT NULL DEFAULT 1
);
GO

-- Initialize the settings table if it doesn't already exist
IF NOT EXISTS (SELECT 1 FROM dbo.Settings)
BEGIN
    INSERT INTO dbo.Settings (AlertEnabled) VALUES (1);
END
GO