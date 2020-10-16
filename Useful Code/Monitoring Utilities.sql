IF SCHEMA_ID('Monitor') IS NULL
	EXECUTE ('CREATE SCHEMA Monitor;');
GO

IF OBJECT_ID('Monitor.TableRowCount','U') IS NULL
	CREATE TABLE Monitor.TableRowCount
	(
			SchemaName  sysname NOT NULL,
			TableName   sysname NOT NULL,
			CaptureDate AS (CAST(CaptureTime AS date)) PERSISTED NOT NULL,
			CaptureTime datetime2(0)    NOT NULL,
			Rows        int NOT NULL, --proper name, rowcount is reserved
			ObjectType  sysname NOT NULL,
			CONSTRAINT PKTableRowCount 
				  PRIMARY KEY (SchemaName, TableName, CaptureDate)
	);
GO

CREATE OR ALTER PROCEDURE Monitor.TableRowCount$CaptureRowcounts
(
	@RecaptureTodaysValues bit = 0
)
AS
-- ----------------------------------------------------------------
-- Monitor the row counts of all tables in the database on a daily basis
-- Error handling not included for example clarity
--
-- NOTE: This code expects the Monitor.TableRowCount to be in the same 
--      db as the  tables being monitored. Rework would be needed if this 
--      is not a possibility
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org
-- ----------------------------------------------------------------

SET XACT_ABORT ON; --simple error handling, rollback on any error

BEGIN TRANSACTION;

IF @RecaptureTodaysValues = 1
  DELETE 
  FROM Monitor.TableRowCount 
  WHERE CaptureDate = CAST(SYSDATETIME() as date);

-- The CTE is used to set up the set of rows to put into the 
--  Monitor.TableRowCount table
WITH CurrentRowcount AS (
SELECT OBJECT_SCHEMA_NAME(partitions.object_id) AS SchemaName, 
       OBJECT_NAME(partitions.object_id) AS TableName, 
       SYSDATETIME() AS CaptureTime,
       SUM(rows) AS Rows,
       objects.type_desc AS ObjectType
FROM   sys.partitions
          JOIN sys.objects
               ON partitions.object_id = objects.object_id
WHERE  index_id in (0,1) --Heap 0 or Clustered 1 "indexes"
AND    object_schema_name(partitions.object_id) NOT IN ('sys')
--the GROUP BY handles partitioned tables with > 1 partition
GROUP BY partitions.object_id, objects.type_desc)

--MERGE allows this procedure to be run > 1 a day without concern, 
--it will update if the row for the day exists
MERGE  Monitor.TableRowCount
USING  (SELECT SchemaName, TableName, CaptureTime, Rows, ObjectType 
        FROM CurrentRowcount) AS Source 
               ON (Source.SchemaName = TableRowCount.SchemaName
                   AND Source.TableName = TableRowCount.TableName
                   AND CAST(Source.CaptureTime AS date) = 
                                          TableRowCount.CaptureDate)
WHEN NOT MATCHED THEN
        INSERT (SchemaName, TableName, CaptureTime, Rows, ObjectType) 
        VALUES (Source.SchemaName, Source.TableName, Source.CaptureTime, 
                Source.Rows, Source.ObjectType);

COMMIT TRANSACTION;
GO

