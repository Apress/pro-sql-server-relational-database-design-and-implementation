--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
EXIT

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--On-Disk Indexes
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

SELECT DB_NAME(df.database_id) AS DatabaseName,
	   CASE WHEN fg.name IS NULL 
         --other, such as logs
         THEN CONCAT('OTHER-',df.type_desc COLLATE database_default)
                     ELSE fg.name END AS FileGroup,
       df.name AS LogicalFileName,
       df.physical_name AS PhysicalFileName
FROM   sys.filegroups AS fg
         RIGHT JOIN sys.master_files AS df
            ON fg.data_space_id = df.data_space_id
ORDER BY DatabaseName, CASE WHEN fg.name IS NOT NULL THEN 0 ELSE 1 END,
		 fg.name, df.type_desc;

----------------------------------------------------------------------------------------------------------
--*****
--Clustered Indexes
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Structure
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Using the Clustered Index
----------------------------------------------------------------------------------------------------------
USE WideWorldImporters;
GO
SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities;
GO
SET SHOWPLAN_TEXT OFF;
GO



SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityID = 23629; --A favorite city of mine, indeed.
GO
SET SHOWPLAN_TEXT OFF;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE CityID = CAST(23629 AS int)
GO
SET SHOWPLAN_TEXT OFF;
GO



SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityID IN (23629,334);
GO
SET SHOWPLAN_TEXT OFF;
GO


SET STATISTICS IO ON;
GO
SELECT *
FROM   [Application].[Cities]
WHERE  CityID IN (23629,334);
GO
SET STATISTICS IO OFF;

----------------------------------------------------------------------------------------------------------
--*****
--Nonclustered Indexes
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Using the Nonclustered Index 
----------------------------------------------------------------------------------------------------------

--
--General Considerations
--

SELECT CONCAT(OBJECT_SCHEMA_NAME(i.object_id),'.',OBJECT_NAME(i.object_id)) 
                                                              AS ObjectName
      , CASE WHEN i.is_unique = 1 THEN 'UNIQUE ' ELSE '' END +
                i.TYPE_DESC AS IndexType
      , i.name AS IndexName
      , user_seeks AS UserSeeks, user_scans AS UserScans
	  , user_lookups AS UserLookups, user_updates AS UserUpdates
FROM  sys.indexes AS i 
         LEFT OUTER JOIN sys.dm_db_index_usage_stats AS s 
              ON i.object_id = s.object_id 
                AND i.index_id = s.index_id 
                AND database_id = DB_ID()
WHERE  OBJECTPROPERTY(i.object_id , 'IsUserTable') = 1 
ORDER  BY ObjectName, IndexName;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityName = 'Nashville';
GO
SET SHOWPLAN_TEXT OFF;
GO

CREATE INDEX CityName ON Application.Cities(CityName) ON USERDATA; 
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityName = 'Nashville';
GO
SET SHOWPLAN_TEXT OFF;
GO


--
--Determining Index Usefulness
--
DBCC SHOW_STATISTICS('Application.Cities', 'CityName') WITH DENSITY_VECTOR;
DBCC SHOW_STATISTICS('Application.Cities', 'CityName') WITH HISTOGRAM;
GO



USE tempdb;
GO
CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.TestIndex
(
    TestIndex int IDENTITY(1,1) CONSTRAINT PKTestIndex PRIMARY KEY,
    BitValue bit,
    Filler char(2000) NOT NULL 
      CONSTRAINT DFLTTestIndex_Filler DEFAULT (REPLICATE('A',2000))
);
CREATE INDEX BitValue ON Demo.TestIndex(bitValue);
GO

SET NOCOUNT ON; --or you will get back 50100 1 row affected messages
INSERT INTO Demo.TestIndex(BitValue)
VALUES (0);
GO 50000 --runs current batch 50000 times in Management Studio.

INSERT INTO Demo.TestIndex(BitValue)
VALUES (1);
GO 100 --puts 100 rows into table with value 1


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   demo.testIndex
WHERE  bitValue = 0;

GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   demo.testIndex
WHERE  bitValue = 1;

GO
SET SHOWPLAN_TEXT OFF;
GO

DBCC SHOW_STATISTICS('Demo.TestIndex', 'BitValue')  WITH HISTOGRAM;
GO

CREATE INDEX BitValueOneOnly 
      ON Demo.TestIndex(BitValue) WHERE BitValue = 1; 
GO

--
--Indexing and Multiple Columns
--

--Composite Indexes
USE WideWorldImporters;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityName = 'Nashville'
  AND  LatestRecordedPopulation = 601222;  
GO
SET SHOWPLAN_TEXT OFF;
GO

SELECT CityName, LatestRecordedPopulation, COUNT(*) AS [Count]
FROM   Application.Cities
GROUP BY CityName, LatestRecordedPopulation
ORDER BY CityName, LatestRecordedPopulation;
GO

SELECT COUNT(DISTINCT CityName) AS CityName,
       SUM(CASE WHEN CityName IS NULL THEN 1 ELSE 0 END) AS NULLCity,
       COUNT(DISTINCT LatestRecordedPopulation) 
                                         AS LatestRecordedPopulation,
       SUM(CASE WHEN LatestRecordedPopulation IS NULL THEN 1 ELSE 0 END) 
                                         AS NULLLatestRecordedPopulation
FROM   Application.Cities;
GO

CREATE INDEX CityNameAndLastRecordedPopulation
         ON Application.Cities (CityName, LatestRecordedPopulation);
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.Cities
WHERE  CityName = 'Nashville'
  AND  LatestRecordedPopulation = 601222;  
GO
SET SHOWPLAN_TEXT OFF;
GO

--Covering Indexes


SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation
FROM   Application.Cities; 
GO
SET SHOWPLAN_TEXT OFF;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation, LastEditedBy
FROM   Application.Cities;
GO
SET SHOWPLAN_TEXT OFF;
GO

DROP INDEX CityNameAndLastRecordedPopulation
         ON Application.Cities;

CREATE INDEX CityNameAndLastRecordedPopulation
         ON Application.Cities (CityName, LatestRecordedPopulation)
                 INCLUDE (LastEditedBy);
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation, LastEditedBy
FROM   Application.Cities;
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT LatestRecordedPopulation, LastEditedBy
FROM   Application.Cities;
GO
SET SHOWPLAN_TEXT OFF;
GO

--Multiple Indexes


SET SHOWPLAN_TEXT ON;
GO
--limiting output to make the plan easier to follow
SELECT CityName, StateProvinceID 
FROM   Application.Cities
WHERE  CityName = 'Nashville'
  AND  StateProvinceID = 44; 
GO
SET SHOWPLAN_TEXT OFF;
GO

--Sort Order of Index Keys


SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation
FROM   Application.Cities
ORDER BY CityName ASC, LatestRecordedPopulation DESC; 
GO
SET SHOWPLAN_TEXT OFF;
GO

DROP INDEX CityNameAndLastRecordedPopulation
         ON Application.Cities;

CREATE INDEX CityNameAndLastRecordedPopulation
         ON Application.Cities (CityName, LatestRecordedPopulation DESC)
                 INCLUDE (LastEditedBy); 

SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation
FROM   Application.Cities
ORDER BY CityName ASC, LatestRecordedPopulation DESC; 
GO
SET SHOWPLAN_TEXT OFF;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT CityName, LatestRecordedPopulation
FROM   Application.Cities
ORDER BY CityName DESC, LatestRecordedPopulation ASC; 
GO
SET SHOWPLAN_TEXT OFF;
GO

--
--Nonclustered Indexes on a Heap
--

SELECT *
INTO   Application.HeapCities
FROM   Application.Cities;

ALTER TABLE Application.HeapCities
   ADD CONSTRAINT PKHeapCities PRIMARY KEY NONCLUSTERED (CityID);

CREATE INDEX CityName ON Application.HeapCities(CityName) ON USERDATA;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Application.HeapCities
WHERE  CityID = 23629;
GO
SET SHOWPLAN_TEXT OFF;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Memory-Optimized Indexes and Data Structures
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Memory Optimized Tables
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Index Structure
----------------------------------------------------------------------------------------------------------

--
--Indexing Memory Optimized Tables
--


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.VehicleTemperatures;
GO
SET SHOWPLAN_TEXT OFF;
GO




SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 2332;
GO
SET SHOWPLAN_TEXT OFF;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID <> 0;
GO
SET SHOWPLAN_TEXT OFF;
GO


ALTER TABLE Warehouse.VehicleTemperatures ADD INDEX RecordedWhen
--33000 distinct values, values are in powers of 2
    HASH (RecordedWhen) WITH (BUCKET_COUNT = 64000); 
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.VehicleTemperatures
WHERE  RecordedWhen = '2016-03-10 12:50:22.0000000';
GO
SET SHOWPLAN_TEXT OFF;
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.VehicleTemperatures
WHERE  RecordedWhen BETWEEN 
          '2016-03-10 12:50:22.0000000' AND '2016-03-10 12:50:22.0000000';
GO
SET SHOWPLAN_TEXT OFF;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Common OLTP Patterns of Index Usage
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Indexed Views
--*****
----------------------------------------------------------------------------------------------------------


CREATE VIEW Warehouse.StockItemSalesTotals
WITH SCHEMABINDING --schemabinding required
AS
SELECT StockItems.StockItemName,
       --ISNULL because expression can't be nullable
       SUM(OrderLines.Quantity * ISNULL(OrderLines.UnitPrice,0)) 
                                                   AS TotalSalesAmount,
       --must use COUNT_BIG for indexed view
       COUNT_BIG(*) AS TotalSalesCount
FROM  Warehouse.StockItems 
          JOIN Sales.OrderLines 
                 ON  OrderLines.StockItemID = StockItems.StockItemID
GROUP  BY StockItems.StockItemName;
GO

SELECT *
FROM   Warehouse.StockItemSalesTotals;
GO


CREATE UNIQUE CLUSTERED INDEX XPKStockItemSalesTotals on
                      Warehouse.StockItemSalesTotals(StockItemName);
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT *
FROM   Warehouse.StockItemSalesTotals;
GO
SET SHOWPLAN_TEXT OFF;
GO


SELECT *
FROM   Warehouse.StockItemSalesTotals
OPTION (EXPAND VIEWS);
GO


SET SHOWPLAN_TEXT ON;
GO
SELECT StockItems.StockItemName,
       SUM(OrderLines.Quantity * ISNULL(OrderLines.UnitPrice,0)) / 
                              COUNT(*) AS AverageSaleAmount 
FROM  Warehouse.StockItems 
          JOIN Sales.OrderLines 
                 ON  OrderLines.StockItemID = StockItems.StockItemID
GROUP  BY StockItems.StockItemName;
GO
SET SHOWPLAN_TEXT OFF;
GO


----------------------------------------------------------------------------------------------------------
--*****
--Compression
--*****
----------------------------------------------------------------------------------------------------------

USE Tempdb
GO
CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.TestCompression
(
    TestCompressionId int,
    Value  int
) 
WITH (DATA_COMPRESSION = ROW) -- PAGE or NONE;

--change compression to PAGE
ALTER TABLE Demo.TestCompression REBUILD WITH (DATA_COMPRESSION = PAGE);

CREATE CLUSTERED INDEX Value
   ON Demo.TestCompression (Value) WITH ( DATA_COMPRESSION = ROW );

ALTER INDEX Value  ON Demo.TestCompression 
REBUILD WITH ( DATA_COMPRESSION = PAGE );

----------------------------------------------------------------------------------------------------------
--*****
--Partitioning
--*****
----------------------------------------------------------------------------------------------------------

USE Tempdb;
GO
--Note that the PARTITION FUNCTION is not a schema owned object
CREATE PARTITION FUNCTION PartitionFunction$Dates (date)
AS RANGE LEFT FOR VALUES ('20140101','20150101');  
                  --set based on recent version of 
                  --WideWorldImporters.Sales.Orders table to show
                  --partition utilization
GO
CREATE PARTITION SCHEME PartitonScheme$Dates
                AS PARTITION PartitionFunction$Dates ALL to ( [PRIMARY] );
GO

CREATE SCHEMA Processing;
GO
CREATE TABLE Processing.SalesOrder
(
    SalesOrderId     int,
    CustomerId  int,
    OrderDate  date,
    CONSTRAINT PKOrder PRIMARY KEY 
                   NONCLUSTERED (SalesOrderId) ON [Primary],
    CONSTRAINT AKOrder UNIQUE CLUSTERED (SalesOrderId, OrderDate)
) ON PartitonScheme$Dates (OrderDate);
GO

INSERT INTO Processing.SalesOrder (SalesOrderId, CustomerId, OrderDate)
SELECT OrderId, CustomerId, OrderDate
FROM  WideWorldImporters.Sales.Orders;
GO


SELECT *, $partition.PartitionFunction$dates(OrderDate) as Partition
FROM   Processing.SalesOrder;
GO

SELECT  partitions.partition_number, partitions.index_id, 
        partitions.rows, indexes.name, indexes.type_desc
FROM    sys.partitions as partitions
           JOIN sys.indexes as indexes
               on indexes.object_id = partitions.object_id
                   and indexes.index_id = partitions.index_id
WHERE   partitions.object_id = object_id('Processing.SalesOrder');
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Indexing Dynamic Management View Queries
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Missing Indexes
--*****
----------------------------------------------------------------------------------------------------------
SELECT ddmid.statement AS object_name, ddmid.equality_columns, 
       ddmid.inequality_columns, ddmid.included_columns,  
       ddmigs.user_seeks, ddmigs.user_scans, 
       ddmigs.last_user_seek, ddmigs.last_user_scan, 
       ddmigs.avg_total_user_cost,
       ddmigs.avg_user_impact, ddmigs.unique_compiles 
FROM   sys.dm_db_missing_index_groups AS ddmig
         JOIN sys.dm_db_missing_index_group_stats AS ddmigs
                ON ddmig.index_group_handle = ddmigs.group_handle
         JOIN sys.dm_db_missing_index_details AS ddmid
                ON ddmid.index_handle = ddmig.index_handle
ORDER BY ((user_seeks + user_scans) * avg_total_user_cost * 
           (avg_user_impact * 0.01)) DESC;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Fragmentation
--*****
----------------------------------------------------------------------------------------------------------

SELECT  s.[name] AS SchemaName,
        o.[name] AS TableName,
        i.[name] AS IndexName,
        f.[avg_fragmentation_in_percent] AS FragPercent,
        f.fragment_count ,
        f.forwarded_record_count --heap only
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, DEFAULT) f
        JOIN sys.indexes i 
             ON f.[object_id] = i.[object_id] 
                AND f.[index_id] = i.[index_id]
        JOIN sys.objects o 
             ON i.[object_id] = o.[object_id]
        JOIN sys.schemas s 
             ON o.[schema_id] = s.[schema_id]
WHERE o.[is_ms_shipped] = 0
  AND i.[is_disabled] = 0; -- skip disabled indexes
GO

----------------------------------------------------------------------------------------------------------
--*****
--On-Disk Index Statistics
--*****
----------------------------------------------------------------------------------------------------------

SELECT OBJECT_SCHEMA_NAME(indexes.object_id) + '.' +
       OBJECT_NAME(indexes.object_id) AS objectName,
       indexes.name, 
       CASE when is_unique = 1 THEN 'UNIQUE ' 
              else '' END + indexes.type_desc AS index_type, 
       ddius.user_seeks, ddius.user_scans, ddius.user_lookups, 
       ddius.user_updates, last_user_lookup, last_user_scan, last_user_seek,last_user_update
FROM   sys.indexes
          LEFT OUTER JOIN sys.dm_db_index_usage_stats ddius
               ON indexes.object_id = ddius.object_id
                   AND indexes.index_id = ddius.index_id
                   AND ddius.database_id = DB_ID()
WHERE OBJECT_SCHEMA_NAME(indexes.object_id) NOT IN ('sys','INFORMATION_SCHEMA')
ORDER  BY ddius.user_seeks + ddius.user_scans + ddius.user_lookups DESC;

----------------------------------------------------------------------------------------------------------
--*****
--Memory Optimized Table Index Stats
--*****
----------------------------------------------------------------------------------------------------------
SELECT OBJECT_SCHEMA_NAME(object_id) + '.' +
       OBJECT_NAME(object_id) AS objectName,
           memory_allocated_for_table_kb,memory_used_by_table_kb,
           memory_allocated_for_indexes_kb,memory_used_by_indexes_kb
FROM sys.dm_db_xtp_table_memory_stats;
GO

SELECT OBJECT_SCHEMA_NAME(ddxis.object_id) + '.' +
       OBJECT_NAME(ddxis.object_id) AS objectName,
           ISNULL(indexes.name,'BaseTable') AS indexName, 
           scans_started, rows_returned, rows_touched, 
           rows_expiring, rows_expired,
           rows_expired_removed, phantom_scans_started 
           --and several other phantom columns
FROM   sys.dm_db_xtp_index_stats AS ddxis
                 JOIN sys.indexes
                        ON indexes.index_id = ddxis.index_id
                          AND indexes.object_id = ddxis.object_id;
GO

SELECT OBJECT_SCHEMA_NAME(ddxhis.object_id) + '.' +
       OBJECT_NAME(ddxhis.object_id) AS objectName,
           ISNULL(indexes.name,'BaseTable') AS indexName, 
           ddxhis.total_bucket_count, ddxhis.empty_bucket_count,
           ddxhis.avg_chain_length, ddxhis.max_chain_length
FROM   sys.dm_db_xtp_hash_index_stats ddxhis
                 JOIN sys.indexes
                        ON indexes.index_id = ddxhis.index_id
                          AND indexes.object_id = ddxhis.object_id;
GO