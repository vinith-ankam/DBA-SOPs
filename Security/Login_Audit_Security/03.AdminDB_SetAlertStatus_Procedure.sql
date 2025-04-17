USE AdminDB;
GO

CREATE PROCEDURE dbo.SetAlertStatus
    @EnableAlert BIT
AS
BEGIN
    UPDATE dbo.Settings
    SET AlertEnabled = @EnableAlert;
END;
GO