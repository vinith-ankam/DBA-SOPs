--Enable Alerts
EXEC AdminDB.dbo.SetAlertStatus @EnableAlert = 1;

--Disable Alerts
EXEC AdminDB.dbo.SetAlertStatus @EnableAlert = 0;
