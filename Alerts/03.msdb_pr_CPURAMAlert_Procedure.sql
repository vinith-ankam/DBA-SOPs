USE msdb;
GO

CREATE PROCEDURE dbo.pr_CPURAMAlert
AS
BEGIN
    DECLARE @SQLServerCPU INT, 
            @TotalMemoryMB INT, @AvailableMemoryMB INT,
            @ServerName NVARCHAR(128), @CurrentDateTime NVARCHAR(100),
            @CPULimit INT = 80, -- 80% CPU limit
            @MemoryLimit INT = 1024, -- Less than 1 GB available triggers an alert --change_Me
            @TotalRAM INT = 16384, -- 16 GB total RAM --change
            @IsThresholdExceeded BIT, -- To track if the threshold is currently exceeded
            @AlertSubject NVARCHAR(255), @NormalSubject NVARCHAR(255),
            @AlertBody NVARCHAR(MAX), @NormalBody NVARCHAR(MAX),
            @ThresholdDetails NVARCHAR(255); -- Threshold details for logging

    -- Get Server Name and Current DateTime for alert email
    SELECT @ServerName = @@SERVERNAME;
    SELECT @CurrentDateTime = CONVERT(NVARCHAR(100), GETDATE(), 120); -- Format: YYYY-MM-DD HH:MI:SS

    -- Get SQL Server CPU Usage
    SELECT @SQLServerCPU = cpu_idle - 100
    FROM (
        SELECT 100.0 - SUM(runnable_tasks_count) * 100.0 / SUM(current_tasks_count) AS cpu_idle
        FROM sys.dm_os_schedulers
        WHERE scheduler_id < 255
    ) AS CPUStats;

    -- Get Memory Usage
    SELECT
        @TotalMemoryMB = total_physical_memory_kb / 1024,
        @AvailableMemoryMB = available_physical_memory_kb / 1024
    FROM sys.dm_os_sys_memory;

    -- Get the current threshold state from ServerStatus table
    SELECT @IsThresholdExceeded = IsThresholdExceeded
    FROM AdminDB.dbo.ServerStatus
    WHERE ServerName = @ServerName;

    -- Initialize ThresholdDetails
    SET @ThresholdDetails = 'CPU Usage: ' + CAST(@SQLServerCPU AS NVARCHAR(10)) + '%, ' + 
                            'Available Memory: ' + CAST(@AvailableMemoryMB AS NVARCHAR(10)) + 'MB out of ' + CAST(@TotalRAM AS NVARCHAR(10)) + 'MB.';

    -- Case 1: CPU or Memory Threshold Exceeded
    IF (@SQLServerCPU > @CPULimit OR @AvailableMemoryMB < @MemoryLimit)
    BEGIN
        IF (@IsThresholdExceeded = 0) -- Threshold was previously normal
        BEGIN
            -- Prepare subject and body for alert email
            SET @AlertSubject = 'Alert: CPU/Memory Issue on ' + @ServerName + ' at ' + @CurrentDateTime;
            SET @AlertBody = 'CPU or Memory threshold exceeded on ' + @ServerName + '.' + CHAR(10) + 
                             'Details:' + CHAR(10) + @ThresholdDetails;

            -- Send the alert email
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'CIMSAlerts',
                @recipients = 'dba_team@yourcompany.com', --change_Me_Mail_Address
                @subject = @AlertSubject,
                @body = @AlertBody;

            -- Update the ServerStatus table
            UPDATE AdminDB.dbo.ServerStatus
            SET IsThresholdExceeded = 1, LastCheckTime = GETDATE()
            WHERE ServerName = @ServerName;
        END

        -- Log the CPU and memory usage in CPURAMUsageLog table
        INSERT INTO AdminDB.dbo.CPURAMUsageLog (ServerName, CheckTime, CPUUsagePercent, AvailableMemoryMB, TotalMemoryMB, IsThresholdExceeded, ThresholdDetails)
        VALUES (@ServerName, GETDATE(), @SQLServerCPU, @AvailableMemoryMB, @TotalMemoryMB, 1, 'CPU or Memory threshold exceeded: ' + @ThresholdDetails);
    END

    -- Case 2: CPU and Memory have returned to normal
    ELSE IF (@SQLServerCPU <= @CPULimit AND @AvailableMemoryMB >= @MemoryLimit)
    BEGIN
        IF (@IsThresholdExceeded = 1) -- Threshold was previously exceeded
        BEGIN
            -- Prepare subject and body for normal state email
            SET @NormalSubject = 'Normal: CPU/Memory Restored on ' + @ServerName + ' at ' + @CurrentDateTime;
            SET @NormalBody = 'CPU and Memory have returned to normal on ' + @ServerName + '.' + CHAR(10) + 
                              'Details:' + CHAR(10) + @ThresholdDetails;

            -- Send the normal state email
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'CIMSAlerts',
                @recipients = 'dba_team@yourcompany.com', --change_Me_Mail_Address
                @subject = @NormalSubject,
                @body = @NormalBody;

            -- Update the ServerStatus table
            UPDATE AdminDB.dbo.ServerStatus
            SET IsThresholdExceeded = 0, LastCheckTime = GETDATE()
            WHERE ServerName = @ServerName;
        END

        -- Log the CPU and memory usage in CPURAMUsageLog table
        INSERT INTO AdminDB.dbo.CPURAMUsageLog (ServerName, CheckTime, CPUUsagePercent, AvailableMemoryMB, TotalMemoryMB, IsThresholdExceeded, ThresholdDetails)
        VALUES (@ServerName, GETDATE(), @SQLServerCPU, @AvailableMemoryMB, @TotalMemoryMB, 0, 'CPU and Memory returned to normal: ' + @ThresholdDetails);
    END
END
GO
