

DECLARE @spidToWatch int = NULL;

--declare @spidToWatch int = 53

--query taken from: https://www.simple-talk.com/sql/database-administration/investigating-transactions-using-dynamic-management-objects/
--written by Timothy Ford (adapted from adapted from a chapter of 'Performance Tuning with SQL Server Dynamic Management' by Tim and myself..
--free ebook version available here: https://www.simple-talk.com/books/sql-books/performance-tuning-with-sql-server-dynamic-management-views/
SELECT   CONCAT(DTL.request_session_id,
                CASE WHEN COALESCE(DER.blocking_session_id, 0) <> 0
                         THEN '/' + CAST(DER.blocking_session_id AS varchar(10))
                     ELSE NULL
                END) AS [session/blocker],
         --DB_NAME(DTL.[resource_database_id]) AS [Database], 
         DTL.resource_type,
         CASE WHEN DTL.resource_type IN ( 'DATABASE', 'FILE', 'METADATA' )
                  THEN DTL.resource_type
              WHEN DTL.resource_type = 'OBJECT'
                  THEN OBJECT_NAME(DTL.resource_associated_entity_id, DTL.resource_database_id)
              WHEN DTL.resource_type IN ( 'KEY', 'PAGE', 'RID' )
                  THEN (   SELECT OBJECT_NAME(object_id)
                           FROM   sys.partitions
                           WHERE  sys.partitions.hobt_id = DTL.resource_associated_entity_id)
              ELSE 'Unidentified'
         END AS [Parent Object],
         DTL.request_mode AS [Lock Type],
         DTL.request_status AS [Request Status],
         --DES.[login_name]
         --useless in SSMS 2016 right now. Will report the issue
         --,CASE DTL.request_lifetime
         --  WHEN 0 THEN DEST_R.TEXT
         --  ELSE DEST_C.TEXT
         --END AS [Statement],
         CASE WHEN resource_type = 'OBJECT'
                  THEN OBJECT_NAME(DTL.resource_associated_entity_id)
              ELSE OBJECT_NAME(partitions.object_id)
         END AS ObjectName,
         partitions.index_id,
         indexes.name AS index_name,
         dtl.resource_description	

FROM     sys.dm_tran_locks DTL
         INNER JOIN sys.dm_exec_sessions DES
             ON DTL.request_session_id = DES.session_id
         INNER JOIN sys.dm_exec_connections DEC
             ON DTL.request_session_id = DEC.most_recent_session_id
         LEFT JOIN sys.partitions
             ON partitions.hobt_id = DTL.resource_associated_entity_id
         LEFT JOIN sys.indexes
             ON indexes.object_id = partitions.object_id
                 AND indexes.index_id = partitions.index_id

         LEFT JOIN sys.dm_exec_requests DER
             ON DTL.request_session_id = DER.session_id

         OUTER APPLY sys.dm_exec_sql_text(DEC.most_recent_sql_handle) AS DEST_C
         OUTER APPLY sys.dm_exec_sql_text(DER.sql_handle) AS DEST_R
WHERE    DTL.resource_database_id = DB_ID()
    AND (   DTL.request_session_id = @spidToWatch
            OR @spidToWatch IS NULL) --My Connection
ORDER BY DTL.request_session_id;
