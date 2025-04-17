USE [AdminDB]
GO

/****** Object:  StoredProcedure [dbo].[pr_get_Logins]    Script Date: 11/7/2024 6:12:18 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[pr_get_Logins]
    @RecipientEmail NVARCHAR(MAX) = NULL,
    @LoginName NVARCHAR(128) = NULL  -- Optional parameter to filter by specific login
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @snapshot_datetime DATETIME = GETDATE();
    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @results NVARCHAR(MAX) = N'';
    DECLARE @htmlHeader NVARCHAR(MAX);
    DECLARE @htmlFooter NVARCHAR(MAX);
    DECLARE @instance_name NVARCHAR(128);
    DECLARE @EmailSubject NVARCHAR(255);

    -- Get the instance name
    SELECT @instance_name = @@SERVERNAME;

    -- HTML header for the email body
    SET @htmlHeader = N'<html><head><style>
        body { font-family: Calibri; font-size: 11pt; font-weight: bold; color: #29465B; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 2px double black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        </style></head><body>
        <p>Hi Team,</p>
        <p>Greetings of the Day!</p>
        <p>Please Find Below SQL Server Login Permissions Report of the ' + @instance_name + N'.</p>
        <table><tr><th>slno</th><th>instance_name</th><th>login</th><th>login_desc</th><th>db_access</th>
        <th>is_disabled</th><th>create_date</th><th>modify_date</th><th>default_database_name</th>
        <th>default_language_name</th><th>is_policy_checked</th><th>is_expiration_checked</th><th>snapshot_datetime</th></tr>';

    -- HTML footer for the email body
    SET @htmlFooter = N'</table><p>Thank you,</p><p>Best Regards,</p><p>Vinith.</p>
        <p><b><u>Sr Database Administrator,</u></b><br><b><u>CIMS.</u></b><br>
        <span style="font-size: 10pt; color: grey;">Mobile: (+91)9000989219 | E-Mail: vinith.ankam@cloudimsystems.com</span></p></body></html>';

    -- Create a temporary table to store the results
    CREATE TABLE #LoginPermissions (
        LoginName NVARCHAR(128),
        DatabaseName NVARCHAR(128),
        PermissionOrRole NVARCHAR(128)
    );

    -- Generate SQL to gather permissions from all databases
    SELECT @sql = @sql +
        N'USE [' + name + N'];
        INSERT INTO #LoginPermissions (LoginName, DatabaseName, PermissionOrRole)
        SELECT 
            sp.name AS LoginName,
            DB_NAME() AS DatabaseName,
            p.permission_name AS PermissionOrRole
        FROM sys.database_permissions p
        JOIN sys.database_principals dp ON p.grantee_principal_id = dp.principal_id
        JOIN sys.server_principals sp ON dp.sid = sp.sid
        WHERE dp.type IN (''S'', ''U'', ''C'') AND p.class_desc = ''DATABASE''
        UNION ALL
        SELECT 
            sp.name AS LoginName,
            DB_NAME() AS DatabaseName,
            rp.name AS PermissionOrRole
        FROM sys.database_role_members drm
        JOIN sys.database_principals dp ON drm.member_principal_id = dp.principal_id
        JOIN sys.server_principals sp ON dp.sid = sp.sid
        JOIN sys.database_principals rp ON drm.role_principal_id = rp.principal_id
        WHERE dp.type IN (''S'', ''U'', ''C'')'
    FROM sys.databases
    WHERE state = 0; -- Only for online databases

    EXEC sp_executesql @sql;

    -- Format and query the results
    WITH RoleMembership AS (
        SELECT
            sp.name AS LoginName,
            CASE 
                WHEN srm.role_principal_id IS NOT NULL THEN 1
                ELSE 0
            END AS IsSysAdmin
        FROM sys.server_principals sp
        LEFT JOIN sys.server_role_members srm 
            ON sp.principal_id = srm.member_principal_id 
            AND srm.role_principal_id = (SELECT principal_id FROM sys.server_principals WHERE name = 'sysadmin')
        WHERE sp.type IN ('S', 'U', 'G', 'C')
    ),
    FormattedPermissions AS (
        SELECT DISTINCT
            sp.name AS LoginName,
            CASE 
                WHEN sp.is_disabled = 1 THEN 1
                ELSE 0
            END AS is_disabled,
            sp.create_date,
            sp.modify_date,
            sp.default_database_name,
            sp.default_language_name,
            ISNULL(sl.is_policy_checked, 0) AS is_policy_checked,
            ISNULL(sl.is_expiration_checked, 0) AS is_expiration_checked,
            CASE
                WHEN rm.IsSysAdmin = 1 THEN N'[master:sysadmin]'
                ELSE N'[' + lp.DatabaseName + N':' + lp.PermissionOrRole + N']'
            END AS PermissionString
        FROM sys.server_principals sp
        LEFT JOIN sys.sql_logins sl ON sp.principal_id = sl.principal_id
        LEFT JOIN #LoginPermissions lp ON sp.name = lp.LoginName
        LEFT JOIN RoleMembership rm ON sp.name = rm.LoginName
        WHERE sp.type IN ('S', 'U', 'G', 'C')
          AND (@LoginName IS NULL OR sp.name = @LoginName)  -- Filter by login name if provided
    )
    SELECT 
        ROW_NUMBER() OVER (ORDER BY fp.LoginName) AS slno,
        @@SERVERNAME AS instance_name,
        fp.LoginName AS login,
        sp.type_desc AS login_desc,
        STUFF((
            SELECT DISTINCT ' ' + PermissionString
            FROM FormattedPermissions fp2
            WHERE fp2.LoginName = fp.LoginName
            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS db_access,
        fp.is_disabled,
        CONVERT(NVARCHAR(20), fp.create_date, 120) AS create_date,
        CONVERT(NVARCHAR(20), fp.modify_date, 120) AS modify_date,
        fp.default_database_name,
        fp.default_language_name,
        fp.is_policy_checked,
        fp.is_expiration_checked,
        CONVERT(NVARCHAR(20), @snapshot_datetime, 120) AS snapshot_datetime
    INTO #Results
    FROM FormattedPermissions fp
    JOIN sys.server_principals sp ON fp.LoginName = sp.name
    GROUP BY 
        fp.LoginName, sp.type_desc, fp.is_disabled, fp.create_date, fp.modify_date, 
        fp.default_database_name, fp.default_language_name, fp.is_policy_checked, fp.is_expiration_checked
    ORDER BY 
        fp.LoginName;

    -- Construct HTML table for email body
    SET @results = @htmlHeader;

    -- Add each row to the results
    DECLARE @slno INT, @login NVARCHAR(128), @login_desc NVARCHAR(128),  
            @db_access NVARCHAR(MAX), @is_disabled BIT, @create_date NVARCHAR(20), @modify_date NVARCHAR(20),  
            @default_database_name NVARCHAR(128), @default_language_name NVARCHAR(128),  
            @is_policy_checked BIT, @is_expiration_checked BIT, @row_snapshot_datetime NVARCHAR(20);  

    DECLARE cur CURSOR FOR   
    SELECT slno, login, login_desc, db_access, is_disabled, create_date, modify_date,  
           default_database_name, default_language_name, is_policy_checked, is_expiration_checked, snapshot_datetime  
    FROM #Results  
    ORDER BY login;  

    OPEN cur;  
    FETCH NEXT FROM cur INTO @slno, @login, @login_desc, @db_access, @is_disabled, @create_date,   
                              @modify_date, @default_database_name, @default_language_name, @is_policy_checked,   
                              @is_expiration_checked, @row_snapshot_datetime;  

    WHILE @@FETCH_STATUS = 0  
    BEGIN  
        SET @results = @results +   
            N'<tr>' +  
            N'<td>' + ISNULL(CAST(@slno AS NVARCHAR(MAX)), '') + N'</td>' +  
            N'<td>' + ISNULL(@instance_name, '') + N'</td>' +  
            N'<td>' + ISNULL(@login, '') + N'</td>' +  
            N'<td>' + ISNULL(@login_desc, '') + N'</td>' +  
            N'<td>' + ISNULL(@db_access, '') + N'</td>' +  
            N'<td>' + ISNULL(CAST(@is_disabled AS NVARCHAR(MAX)), '') + N'</td>' +  
            N'<td>' + ISNULL(@create_date, '') + N'</td>' +  
            N'<td>' + ISNULL(@modify_date, '') + N'</td>' +  
            N'<td>' + ISNULL(@default_database_name, '') + N'</td>' +  
            N'<td>' + ISNULL(@default_language_name, '') + N'</td>' +  
            N'<td>' + ISNULL(CAST(@is_policy_checked AS NVARCHAR(MAX)), '') + N'</td>' +  
            N'<td>' + ISNULL(CAST(@is_expiration_checked AS NVARCHAR(MAX)), '') + N'</td>' +  
            N'<td>' + ISNULL(@row_snapshot_datetime, '') + N'</td>' +  
            N'</tr>';  

        FETCH NEXT FROM cur INTO @slno, @login, @login_desc, @db_access, @is_disabled, @create_date,   
                                  @modify_date, @default_database_name, @default_language_name, @is_policy_checked,   
                                  @is_expiration_checked, @row_snapshot_datetime;  
    END  

    CLOSE cur;  
    DEALLOCATE cur;  

    -- Append the footer to the results
    SET @results = @results + @htmlFooter;

    -- Email subject
    SET @EmailSubject = @instance_name + N' SQL Server Login Permissions Report - ' + CONVERT(NVARCHAR(20), @snapshot_datetime, 120);

    -- Send the email
    IF @RecipientEmail IS NOT NULL
    BEGIN
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'CIMSAlerts',
            @recipients = @RecipientEmail,
			@copy_recipients= 'vinith.ankam@cloudimsystems.com',
            @subject = @EmailSubject,
            @body = @results,
            @body_format = 'HTML';
    END
    ELSE
    BEGIN
        -- If no recipient email is provided, output the results to SSMS
        SELECT * FROM #Results;
    END

    -- Clean up
    DROP TABLE #LoginPermissions;
    DROP TABLE #Results;
END;
GO


