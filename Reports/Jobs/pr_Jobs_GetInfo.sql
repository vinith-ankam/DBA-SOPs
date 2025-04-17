CREATE PROCEDURE pr_Jobs_GetInfo
    @Day INT = NULL,               -- Time range in days from the current timestamp
    @Hours INT = NULL,             -- Time range in hours from the current timestamp
    @StartTime DATETIME = NULL,    -- Specific start time
    @EndTime DATETIME = NULL,      -- Specific end time
    @Status NVARCHAR(50) = 'All',  -- Job status filter ('All', 'Succeeded', 'Failed', 'Retry', etc.)
    @Email NVARCHAR(100) = NULL    -- Email address to send results (if provided)
AS
BEGIN
    -- Declare variables
    DECLARE @CurrentTime DATETIME = GETDATE();
    DECLARE @FilterStartTime DATETIME;
    DECLARE @FilterEndTime DATETIME;
    DECLARE @Subject NVARCHAR(255);
    DECLARE @ServerName NVARCHAR(128) = @@SERVERNAME;  -- Get the server name for the subject line
    DECLARE @StatusText NVARCHAR(50) = UPPER(@Status); -- Capitalize status for dynamic message
    DECLARE @JobCount INT;  -- Variable to hold the count of jobs
    DECLARE @EmailBody NVARCHAR(MAX);  -- To hold the final email body content
    
    -- Set the time range based on @Day or @Hours
    IF @Day IS NOT NULL
    BEGIN
        SET @FilterStartTime = DATEADD(DAY, -@Day, @CurrentTime);
        SET @FilterEndTime = @CurrentTime;
        SET @Subject = 'SQL Job History Report of ' + @ServerName + ' - Last ' + CAST(@Day AS NVARCHAR) + ' Day(s)';
    END
    ELSE IF @Hours IS NOT NULL
    BEGIN
        SET @FilterStartTime = DATEADD(HOUR, -@Hours, @CurrentTime);
        SET @FilterEndTime = @CurrentTime;
        SET @Subject = 'SQL Job History Report of ' + @ServerName + ' - Last ' + CAST(@Hours AS NVARCHAR) + ' Hour(s)';
    END
    ELSE IF @StartTime IS NOT NULL AND @EndTime IS NOT NULL
    BEGIN
        SET @FilterStartTime = @StartTime;
        SET @FilterEndTime = @EndTime;
        SET @Subject = 'SQL Job History Report of ' + @ServerName + ' - From ' + CONVERT(NVARCHAR, @StartTime, 120) + ' to ' + CONVERT(NVARCHAR, @EndTime, 120);
    END
    ELSE
    BEGIN
        SET @FilterStartTime = DATEADD(DAY, -1, @CurrentTime); -- Default to last 24 hours
        SET @FilterEndTime = @CurrentTime;
        SET @Subject = 'SQL Job History Report of ' + @ServerName + ' - Last 24 Hours';
    END

    -- Temporary table for job results
    DECLARE @JobResults TABLE (
        JobName NVARCHAR(128),
        RunDate NVARCHAR(11),  -- Store RunDate as formatted string YYYY-MMM-DD
        RunTime NVARCHAR(8),
        RunStatus NVARCHAR(50),
        JobMessage NVARCHAR(MAX)
    );

    -- Insert job history based on the filters
    INSERT INTO @JobResults (JobName, RunDate, RunTime, RunStatus, JobMessage)
    SELECT 
        jobs.name AS JobName,
        -- Format RunDate as YYYY-MMM-DD
        CONVERT(NVARCHAR(11), CONVERT(DATE, CONVERT(VARCHAR(8), jobhistory.run_date, 112)), 106) AS RunDate,  
        -- Format RunTime properly (HH:MM:SS) and ensure leading zeros for correct sorting
        STUFF(STUFF(RIGHT('000000' + CAST(jobhistory.run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':') AS RunTime, 
        CASE jobhistory.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS RunStatus,
        jobhistory.message AS JobMessage
    FROM 
        msdb.dbo.sysjobhistory jobhistory
    INNER JOIN 
        msdb.dbo.sysjobs jobs ON jobhistory.job_id = jobs.job_id
    WHERE 
        (CONVERT(DATETIME, 
                 CONVERT(VARCHAR(8), jobhistory.run_date, 112) + ' ' + 
                 STUFF(STUFF(RIGHT('000000' + CAST(jobhistory.run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':')) 
        BETWEEN @FilterStartTime AND @FilterEndTime)
        AND (@Status = 'All' OR
             (CASE jobhistory.run_status
                WHEN 0 THEN 'Failed'
                WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry'
                WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress'
                ELSE 'Unknown'
              END = @Status))
    ORDER BY 
        CONVERT(DATE, CONVERT(VARCHAR(8), jobhistory.run_date, 112)),  -- Sort by RunDate
        CAST(STUFF(STUFF(RIGHT('000000' + CAST(jobhistory.run_time AS VARCHAR(6)), 6), 5, 0, ':'), 3, 0, ':') AS TIME);  -- Sort by RunTime

    -- Count the number of jobs returned
    SELECT @JobCount = COUNT(*) FROM @JobResults;

    -- If email is provided, prepare email content
    IF @Email IS NOT NULL
    BEGIN
        IF @JobCount > 0
        BEGIN
            -- Generate the HTML body for the email
            SET @EmailBody = N'<html><body>'
                           + N'Dear Team,<br/><br/>'
                           + N'Please find below the SQL ' + @StatusText + N' Job History Report from Last ' 
                           + CASE 
                                 WHEN @Day IS NOT NULL THEN CAST(@Day AS NVARCHAR) + ' Day(s)'
                                 WHEN @Hours IS NOT NULL THEN CAST(@Hours AS NVARCHAR) + ' Hour(s)'
                                 ELSE 'Specified Time Range'
                             END + ':<br/><br/>'
                           + N'<table border="1" cellpadding="5">'
                           + N'<tr><th>Job Name</th><th>Run Date</th><th>Run Time</th><th>Status</th><th>Message</th></tr>';

            -- Append each row to the email body
            SELECT @EmailBody = @EmailBody +
                                N'<tr><td>' + JobName + N'</td><td>' + RunDate + N'</td><td>' + RunTime + N'</td><td>' + RunStatus + N'</td><td>' + JobMessage + N'</td></tr>'
            FROM @JobResults;

            -- Close the HTML
            SET @EmailBody = @EmailBody + N'</table><br/><br/>'
                            + N'Regards,<br/>DBA Team</body></html>';
        END
        ELSE
        BEGIN
            -- If no jobs found, notify team
            SET @EmailBody = N'<html><body>'
                           + N'Dear Team,<br/><br/>'
                           + N'There were no SQL ' + @StatusText + N' Job History Reports from the Last ' 
                           + CASE 
                                 WHEN @Day IS NOT NULL THEN CAST(@Day AS NVARCHAR) + ' Day(s)'
                                 WHEN @Hours IS NOT NULL THEN CAST(@Hours AS NVARCHAR) + ' Hour(s)'
                                 ELSE 'Specified Time Range'
                             END + '.<br/><br/>'
                           + N'Regards,<br/>DBA Team</body></html>';
        END

        -- Send the email
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'CIMSAlerts',
            @recipients = @Email,
            @subject = @Subject,   -- Updated subject with server name and time range
            @body = @EmailBody,
            @body_format = 'HTML';
    END
    ELSE
    BEGIN
        -- Return results to SSMS if email is not provided
        SELECT 
            JobName, 
            RunDate, 
            RunTime, 
            RunStatus, 
            JobMessage
        FROM @JobResults;
    END
END;