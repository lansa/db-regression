/* =============================================================================
   lansa_diag  -  Extended Events session for LANSA / ODBC Driver 18 diagnostics
   -----------------------------------------------------------------------------
   Captures every message the SQL Server engine emits (including severity 10
   informational messages such as 16954 "Executing SQL directly; no cursor"),
   plus the surrounding cursor API calls and completed statements.

   All timestamps are left in UTC to line up with LANSA trace files.
   =============================================================================
   Note: Load into SSMS, select statements to execute and type Alt-X to execute 
   the selected statements.
*/


/* -----------------------------------------------------------------------------
   1. CREATE THE SESSION   (re-runnable: drops any existing definition first)
   -------------------------------------------------------------------------- */
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'lansa_diag')
    DROP EVENT SESSION [lansa_diag] ON SERVER;
GO

CREATE EVENT SESSION [lansa_diag] ON SERVER
ADD EVENT sqlserver.error_reported (
    ACTION (sqlserver.session_id, sqlserver.sql_text,
            sqlserver.client_app_name, sqlserver.client_hostname,
            sqlserver.username, sqlserver.database_name)
    WHERE severity >= 10          -- 10 is INFORMATIONAL; do not raise this
),
ADD EVENT sqlserver.rpc_completed (
    ACTION (sqlserver.session_id, sqlserver.sql_text,
            sqlserver.client_app_name, sqlserver.client_hostname)
    WHERE object_name LIKE 'sp_cursor%'
),
ADD EVENT sqlserver.sql_statement_completed (
    ACTION (sqlserver.session_id, sqlserver.sql_text,
            sqlserver.client_app_name, sqlserver.client_hostname)
)
ADD TARGET package0.event_file (
    SET filename         = N'C:\Temp\lansa_diag.xel',
        max_file_size    = 50,           -- MB per file
        max_rollover_files = 4
)
WITH (MAX_MEMORY             = 8MB,
      EVENT_RETENTION_MODE   = ALLOW_SINGLE_EVENT_LOSS,
      MAX_DISPATCH_LATENCY   = 5 SECONDS,
      TRACK_CAUSALITY        = ON);      -- groups all events of one request
GO

/* C:\Temp must exist AND be writable by the SQL Server service account.
   The path is validated on START, not on CREATE. */


/* -----------------------------------------------------------------------------
   2. START / STOP
   -------------------------------------------------------------------------- */
ALTER EVENT SESSION [lansa_diag] ON SERVER STATE = START;
--ALTER EVENT SESSION [lansa_diag] ON SERVER STATE = STOP;

-- Confirm it is actually running (NULL create_time = defined but not started)
SELECT s.name, r.create_time
FROM sys.server_event_sessions s
LEFT JOIN sys.dm_xe_sessions r ON r.name = s.name
WHERE s.name = 'lansa_diag';
GO


/* -----------------------------------------------------------------------------
   3. READ THE CAPTURED EVENTS
      utc_time is ISO 8601 with 7 fractional digits, e.g.
          2026-08-14T10:17:36.1067230
      LANSA traces stamp 6 digits (10:17:36.106723) -> compare the first 6.
   -------------------------------------------------------------------------- */
WITH raw AS (
    SELECT CAST(event_data AS XML) AS x
    FROM sys.fn_xe_file_target_read_file('C:\Temp\lansa_diag*.xel', NULL, NULL, NULL)
),
ev AS (
    SELECT
        x.value('(event/@name)[1]', 'varchar(50)')                                     AS event_name,
        CONVERT(varchar(27),
                x.value('(event/@timestamp)[1]', 'datetime2(7)'), 126)                 AS utc_time,
        x.value('(event/@timestamp)[1]', 'datetime2(7)')                               AS utc_time_dt,
        x.value('(event/action[@name="session_id"]/value)[1]', 'int')                   AS spid,
        x.value('(event/data[@name="error_number"]/value)[1]', 'int')                   AS error_number,
        x.value('(event/data[@name="severity"]/value)[1]', 'int')                       AS severity,
        x.value('(event/data[@name="state"]/value)[1]', 'int')                          AS state,
        x.value('(event/data[@name="message"]/value)[1]', 'nvarchar(max)')              AS message,
        x.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)')           AS sql_text,
        x.value('(event/action[@name="client_app_name"]/value)[1]', 'nvarchar(256)')    AS client_app,
        x.value('(event/action[@name="client_hostname"]/value)[1]', 'nvarchar(256)')    AS client_host,
        x.value('(event/action[@name="username"]/value)[1]', 'nvarchar(256)')           AS username,
        x.value('(event/action[@name="database_name"]/value)[1]', 'nvarchar(128)')      AS database_name,
        x.value('(event/action[@name="attach_activity_id"]/value)[1]', 'varchar(50)')   AS activity_id
    FROM raw
)
SELECT utc_time, spid, error_number, severity, state,
       message, sql_text, client_app, client_host, username,
       database_name, activity_id
FROM ev
WHERE event_name = 'error_reported'
--  Widen to see the cursor API calls and completed statements as well:
--WHERE event_name IN ('error_reported','rpc_completed','sql_statement_completed')
--  Suppress routine severity-10 chatter (context / language / dbcc changes):
--  AND ISNULL(error_number,0) NOT IN (5701, 5703, 3621)
ORDER BY utc_time_dt;
GO


/* -----------------------------------------------------------------------------
   4. TEAR DOWN
   -------------------------------------------------------------------------- */
--ALTER EVENT SESSION [lansa_diag] ON SERVER STATE = STOP;
--DROP EVENT SESSION [lansa_diag] ON SERVER;


/* -----------------------------------------------------------------------------
   NOTES
   -----------------------------------------------------------------------------
   * Permissions: ALTER ANY EVENT SESSION, VIEW SERVER PERFORMANCE STATE.
   * MAX_DISPATCH_LATENCY = 5 SECONDS: the newest events may not be on disk yet.
     STOP the session to flush before reading if you need the very last ones.
   * File target buffers, so on-disk order can lag; the timestamps themselves
     remain accurate to when each event fired.
   * activity_id (from TRACK_CAUSALITY) is a GUID with a sequence number after
     a hyphen. Group on the GUID portion to see every diagnostic belonging to
     one request - this is what tells you whether a message like 16954 was the
     only one raised or merely the last one the client happened to read.
   * Filenames get a timestamp appended on rollover, hence the * wildcard.
   -------------------------------------------------------------------------- */