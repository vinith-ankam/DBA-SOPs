USE master;
GO

CREATE OR ALTER TRIGGER trg_LogCimsDBALogins
ON ALL SERVER
FOR LOGON
AS
BEGIN
    DECLARE @LoginName NVARCHAR(256);
    DECLARE @Hostname NVARCHAR(256);
    DECLARE @IPAddress NVARCHAR(50);
    DECLARE @Application NVARCHAR(256);
    DECLARE @SessionID INT;
    DECLARE @EventTime DATETIME;
    DECLARE @AlertEnabled BIT;

    SET @LoginName = ORIGINAL_LOGIN(); -- The login name of the user
    SET @Hostname = HOST_NAME(); -- The name of the client computer
    SET @IPAddress = CONVERT(NVARCHAR(50), CONNECTIONPROPERTY('client_net_address')); -- Modify if needed to get actual IP
    SET @Application = APP_NAME(); -- The application name
    SET @SessionID = @@SPID; -- The session ID
    SET @EventTime = GETDATE(); -- Current time

    -- Check if alerts are enabled
    SELECT @AlertEnabled = AlertEnabled FROM AdminDB.dbo.Settings;

    IF @LoginName = 'cimsdba'
    BEGIN
        -- Log the successful login to the LoginAudit table
        INSERT INTO AdminDB.dbo.LoginAudit (EventType, LoginName, Hostname, IPAddress, Application, SessionID, EventTime)
        VALUES ('LOGIN_SUCCESS', @LoginName, @Hostname, @IPAddress, @Application, @SessionID, @EventTime);

        -- Send an alert if enabled
        IF @AlertEnabled = 1
        BEGIN
            DECLARE @Subject NVARCHAR(100);
            DECLARE @Body NVARCHAR(MAX);
            DECLARE @ServerName NVARCHAR(100);

            -- Get the server name
            SET @ServerName = @@SERVERNAME;

            -- Set the subject
            SET @Subject = 'ALERT: ' + @ServerName + ' - cimsdba login attempt succeeded at ' + CONVERT(NVARCHAR(50), @EventTime, 120);

            -- Build the email body
            SET @Body = '<h1>Unauthorized Access Attempt</h1>' +
                        'Dear Team,<br><br>' +
                        'It has come to our attention that an unauthorized access attempt was made using the "cimsdba" account on "' + @ServerName + '" server.<br><br>' +
                        'As per the compliance guidelines, the use of the "cimsdba" login is strictly prohibited for general access, and this incident has triggered a non-compliance alert.<br><br>' +
                        'Below are the details of the unauthorized attempt:<br><br>' +
                        '<table border="1">' +
                        '<tr><th>Event Type</th><th>Login Name</th><th>Hostname</th><th>IPAddress</th>' +
                        '<th>Application</th><th>Session ID</th><th>Event Time</th></tr>' +
                        '<tr><td>LOGIN_SUCCESS</td>' +
                        '<td>' + @LoginName + '</td>' +
                        '<td>' + @Hostname + '</td>' +
                        '<td>' + @IPAddress + '</td>' +
                        '<td>' + @Application + '</td>' +
                        '<td>' + CONVERT(NVARCHAR(10), @SessionID) + '</td>' +
                        '<td>' + CONVERT(NVARCHAR(20), @EventTime, 120) + '</td>' +
                        '</tr>' +
                        '</table>' +
                        '<br>Regards,<br>DBA Team';

            -- Send the email
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'CIMSAlerts',
                @recipients = 'vinith.ankam@cloudimsystems.com', -- Replace with actual recipient
                @subject = @Subject,
                @body = @Body,
                @body_format = 'HTML'; -- Set body format to HTML
        END
    END
END;
GO