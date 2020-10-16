--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
EXIT

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Transactions
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Transaction Syntax
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Transaction Basics
----------------------------------------------------------------------------------------------------------

BEGIN TRANSACTION one;
ROLLBACK TRANSACTION one;
GO

BEGIN TRANSACTION one;
BEGIN TRANSACTION two;
ROLLBACK TRANSACTION two;
GO

SELECT @@TRANCOUNT
GO

ROLLBACK;
GO


USE Master;
GO

ALTER DATABASE WideWorldImporters
      SET RECOVERY FULL;
GO

EXEC sp_addumpdevice 'disk', 'TestWideWorldImporters ',
                              'C:\temp\WideWorldImporters.bak';
EXEC sp_addumpdevice 'disk', 'TestWideWorldImportersLog',
                              'C:\temp\WideWorldImportersLog.bak';

SELECT  recovery_model_desc
FROM    sys.databases
WHERE   name = 'WideWorldImporters';

SELECT name, type_desc, physical_name
FROM   sys.backup_devices;
GO


BACKUP DATABASE WideWorldImporters TO TestWideWorldImporters;
GO

USE WideWorldImporters;
GO
SELECT COUNT(*)
FROM   Sales.SpecialDeals;

BEGIN TRANSACTION Test WITH MARK 'Test';
DELETE Sales.SpecialDeals;
COMMIT TRANSACTION;

SELECT COUNT(*)
FROM   Sales.SpecialDeals;
GO


BACKUP LOG WideWorldImporters TO TestWideWorldImportersLog;
GO

USE Master
GO
RESTORE DATABASE WideWorldImporters FROM TestWideWorldImporters
                                   WITH REPLACE, NORECOVERY;

RESTORE LOG WideWorldImporters FROM TestWideWorldImportersLog
                                   WITH STOPBEFOREMARK = 'Test', RECOVERY;
GO

ALTER DATABASE WideWorldImporters SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE WideWorldImporters SET MULTI_USER;

USE WideWorldImporters;
GO
SELECT COUNT(*)
FROM   Sales.SpecialDeals;
GO

USE WideWorldImporters;
GO
SELECT COUNT(*)
FROM   Sales.SpecialDeals;

--Clean up your devices
EXEC sp_dropdevice 'TestWideWorldImporters ','DELFILE'
EXEC sp_dropdevice 'TestWideWorldImportersLog ','DELFILE'
GO

----------------------------------------------------------------------------------------------------------
--Nested Transactions
----------------------------------------------------------------------------------------------------------


BEGIN TRANSACTION;
    BEGIN TRANSACTION;
       BEGIN TRANSACTION;
GO

SELECT @@TRANCOUNT;
GO

ROLLBACK TRANSACTION;
GO

SELECT @@TRANCOUNT AS ZeroDeep;
BEGIN TRANSACTION;
SELECT @@TRANCOUNT AS OneDeep;
GO

BEGIN TRANSACTION;
SELECT @@TRANCOUNT AS TwoDeep;
COMMIT TRANSACTION; --commits previous transaction started with BEGIN TRANSACTION
SELECT @@TRANCOUNT AS OneDeep;
GO

COMMIT TRANSACTION;
SELECT @@TRANCOUNT AS ZeroDeep;
GO

BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
BEGIN TRANSACTION;
SELECT @@TRANCOUNT AS InTran;

ROLLBACK TRANSACTION;
SELECT @@TRANCOUNT AS OutTran;
GO

SELECT @@TRANCOUNT;
COMMIT TRANSACTION;
GO

----------------------------------------------------------------------------------------------------------
--Autonomous Transactions
----------------------------------------------------------------------------------------------------------

CREATE DATABASE Chapter12;
GO
USE Chapter12;
GO

CREATE SCHEMA Magic;
GO
CREATE SEQUENCE Magic.Trick_SEQUENCE AS int START WITH 1;
GO
CREATE TABLE Magic.Trick
(
     TrickId int NOT NULL IDENTITY,
     Value int CONSTRAINT DFLTTrick_Value 
                         DEFAULT (NEXT VALUE FOR Magic.Trick_SEQUENCE)
);
GO

BEGIN TRANSACTION;
--just use the default values from table
INSERT INTO Magic.Trick DEFAULT VALUES; 
SELECT TrickId, Value FROM Magic.Trick;
ROLLBACK TRANSACTION;
GO

----------------------------------------------------------------------------------------------------------
--Savepoints
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Arts;
GO
CREATE TABLE Arts.Performer
(
    PerformerId int IDENTITY CONSTRAINT PKPeformer PRIMARY KEY,
    Name varchar(100) CONSTRAINT AKPerformer UNIQUE
);
GO


BEGIN TRANSACTION;
INSERT INTO Arts.Performer(Name) VALUES ('Elvis Costello');

SAVE TRANSACTION SavePoint; --the savepoint name is case sensitive, even if 
--instance is not.
--
--if you reuse a savepoint name, the rollback is to last 

INSERT INTO Arts.Performer(Name) VALUES ('Air Supply');

--don't keep Air Supply, yuck! ...
ROLLBACK TRANSACTION SavePoint;

COMMIT TRANSACTION;

SELECT *
FROM Arts.Performer;

GO


----------------------------------------------------------------------------------------------------------
--Transaction State
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Menu;
GO
CREATE TABLE Menu.FoodItem
(
    FoodItemId int NOT NULL IDENTITY(1,1)
        CONSTRAINT PKFoodItem PRIMARY KEY,
    Name varchar(30) NOT NULL
        CONSTRAINT AKFoodItem_Name UNIQUE,
    Description varchar(60) NOT NULL,
        CONSTRAINT CHKFoodItem_Name CHECK (LEN(Name) > 0),
        CONSTRAINT CHKFoodItem_Description CHECK (LEN(Description) > 0)
);
GO

CREATE TRIGGER Menu.FoodItem$InsertTrigger
ON Menu.FoodItem
AFTER INSERT
AS --Note, minimalist code for demo. Chapter 9 and Appendix B 
   --have more details on complete trigger writing
BEGIN
   BEGIN TRY
        IF EXISTS (SELECT *
                   FROM Inserted
                   WHERE Description LIKE '%Yucky%')
        THROW 50000, 'No ''yucky'' food desired here',1;
   END TRY
   BEGIN CATCH
       IF XACT_STATE() <> 0
          ROLLBACK TRANSACTION;
       THROW;
   END CATCH;
END
GO

SET XACT_ABORT ON;  

BEGIN TRY  
    BEGIN TRANSACTION;  

        --insert the row to be tested
        INSERT INTO Menu.FoodItem(Name, Description)
        VALUES ('Hot Chicken','Nashville specialty, super spicy');

        SELECT  XACT_STATE() AS [XACT_STATE], 
                'Success, commit'  AS Description;
    COMMIT TRANSACTION;  
END TRY  
BEGIN CATCH  
        IF XACT_STATE() = -1 --transaction not doomed, but open
          BEGIN 
                SELECT -1 AS [XACT_STATE], 
                       'Doomed transaction'  AS Description; 
                ROLLBACK TRANSACTION;
          END
        ELSE IF XACT_STATE() = 0 --transaction not doomed, but open
          BEGIN 
                SELECT 0 AS [XACT_STATE], 
                       'No Transaction'  AS Description;;
          END  
        ELSE IF XACT_STATE() = 1 --transaction still active
          BEGIN 
             SELECT 1 AS [XACT_STATE], 
                    'Transction Still Active After Error'  AS Description;
                ROLLBACK TRANSACTION; 
          END  
END CATCH;  
GO

SET XACT_ABORT ON;  

BEGIN TRY  
    BEGIN TRANSACTION;  

        --insert the row to be tested
		INSERT INTO Menu.FoodItem(Name, Description)
		VALUES ('Ethiopian Mexican Vegan Fusion','');


        SELECT  XACT_STATE() AS [XACT_STATE], 
                'Success, commit'  AS Description;
    COMMIT TRANSACTION;  
END TRY  
BEGIN CATCH  
        IF XACT_STATE() = -1 --transaction not doomed, but open
          BEGIN 
                SELECT -1 AS [XACT_STATE], 
                       'Doomed transaction'  AS Description; 
                ROLLBACK TRANSACTION;
          END
        ELSE IF XACT_STATE() = 0 --transaction not doomed, but open
          BEGIN 
                SELECT 0 AS [XACT_STATE], 
                       'No Transaction'  AS Description;;
          END  
        ELSE IF XACT_STATE() = 1 --transaction still active
          BEGIN 
             SELECT 1 AS [XACT_STATE], 
                    'Transction Still Active After Error'  AS Description;
                ROLLBACK TRANSACTION; 
          END  
END CATCH;  
GO


SET XACT_ABORT ON;  

BEGIN TRY  
    BEGIN TRANSACTION;  

        --insert the row to be tested
		INSERT INTO Menu.FoodItem(Name, Description)
		VALUES ('Vegan Cheese','Yucky imitation for the real thing');

        SELECT  XACT_STATE() AS [XACT_STATE], 
                'Success, commit'  AS Description;
    COMMIT TRANSACTION;  
END TRY  
BEGIN CATCH  
        IF XACT_STATE() = -1 --transaction not doomed, but open
          BEGIN 
                SELECT -1 AS [XACT_STATE], 
                       'Doomed transaction'  AS Description; 
                ROLLBACK TRANSACTION;
          END
        ELSE IF XACT_STATE() = 0 --transaction not doomed, but open
          BEGIN 
                SELECT 0 AS [XACT_STATE], 
                       'No Transaction'  AS Description;;
          END  
        ELSE IF XACT_STATE() = 1 --transaction still active
          BEGIN 
             SELECT 1 AS [XACT_STATE], 
                    'Transction Still Active After Error'  AS Description;
                ROLLBACK TRANSACTION; 
          END  
END CATCH;  
GO

ALTER TRIGGER Menu.FoodItem$InsertTrigger
ON Menu.FoodItem
AFTER INSERT
AS --Note, minimalist code for demo. Chapter 7 and Appendix B 
   --have more details on complete trigger writing
BEGIN
        IF EXISTS (SELECT *
                   FROM Inserted
                   WHERE Description LIKE '%Yucky%')
        THROW 50000, 'No ''yucky'' food desired here',1;

END;
GO

SET XACT_ABORT ON;  

BEGIN TRY  
    BEGIN TRANSACTION;  

        --insert the row to be tested
		INSERT INTO Menu.FoodItem(Name, Description)
		VALUES ('Vegan Cheese','Yucky imitation for the real thing');

        SELECT  XACT_STATE() AS [XACT_STATE], 
                'Success, commit'  AS Description;
    COMMIT TRANSACTION;  
END TRY  
BEGIN CATCH  
        IF XACT_STATE() = -1 --transaction not doomed, but open
          BEGIN 
                SELECT -1 AS [XACT_STATE], 
                       'Doomed transaction'  AS Description; 
                ROLLBACK TRANSACTION;
          END
        ELSE IF XACT_STATE() = 0 --transaction not doomed, but open
          BEGIN 
                SELECT 0 AS [XACT_STATE], 
                       'No Transaction'  AS Description;;
          END  
        ELSE IF XACT_STATE() = 1 --transaction still active
          BEGIN 
             SELECT 1 AS [XACT_STATE], 
                    'Transction Still Active After Error'  AS Description;
                ROLLBACK TRANSACTION; 
          END  
END CATCH;  
GO

--back to normal setting
SET XACT_ABORT OFF;  
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--SQL Server Concurrency Methods 
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Isolation Levels
--*****
----------------------------------------------------------------------------------------------------------

SELECT  CASE transaction_isolation_level
            WHEN 1 THEN 'Read Uncomitted'      WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'      WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'             ELSE 'Something is afoot'
         END
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid;
GO

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
GO
SELECT  CASE transaction_isolation_level
            WHEN 1 THEN 'Read Uncomitted'      WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'      WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'             ELSE 'Something is afoot'
         END
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid;
GO

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO
SELECT  CASE transaction_isolation_level
            WHEN 1 THEN 'Read Uncomitted'      WHEN 2 THEN 'Read Committed'
            WHEN 3 THEN 'Repeatable Read'      WHEN 4 THEN 'Serializable'
            WHEN 5 THEN 'Snapshot'             ELSE 'Something is afoot'
         END
FROM    sys.dm_exec_sessions 
WHERE  session_id = @@spid;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Pessimistic Concurrency Enforcement
--*****
----------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------
--*****
--Isolation Levels and Locking
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Art;
GO
CREATE TABLE Art.Artist
(
    ArtistId int CONSTRAINT PKArtist PRIMARY KEY
    ,Name varchar(30) NOT NULL --no key on value for demo purposes
    ,Padding char(4000) 
        DEFAULT (replicate('a',4000)) --so all rows not on single page
                --if all rows are on same page, some optimizations can
                --be made
); 
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (1,'da Vinci'),(2,'Micheangelo'), (3,'Donatello'), 
       (4,'Picasso'),(5,'Dali'), (6,'Jones');  
GO
CREATE TABLE Art.ArtWork
(
    ArtWorkId int CONSTRAINT PKArtWork PRIMARY KEY
    ,ArtistId int NOT NULL 
           CONSTRAINT FKArtwork$wasDoneBy$Art_Artist 
                                  REFERENCES Art.Artist (ArtistId)
    ,Name varchar(30)  NOT NULL
    ,Padding char(4000) DEFAULT (REPLICATE('a',4000)) 
    ,CONSTRAINT AKArtwork UNIQUE (ArtistId, Name)
); 
INSERT Art.Artwork (ArtworkId, ArtistId, Name)
VALUES (1,1,'Last Supper'),(2,1,'Mona Lisa'),(3,6,'Rabbit Fire');

--
--READ UNCOMMITTED
--

--see file Chapter 12 (Connection B).sql for uncommented CONNECTION B statements to coordinate with.

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED; --this is the default, just 
                                                --setting for emphasis
BEGIN TRANSACTION;
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (7, 'McCartney');
GO

----CONNECTION B
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
--SELECT ArtistId, Name
--FROM Art.Artist
--WHERE Name = 'McCartney';
--GO

----Stop the transaction that is blocked

----CONNECTION B
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--SELECT ArtistId, Name
--FROM Art.Artist
--WHERE Name = 'McCartney';
--GO

--CONNECTION A
ROLLBACK TRANSACTION;
GO

----CONNECTION B
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--SELECT ArtistId, Name
--FROM Art.Artist
--WHERE Name = 'McCartney';
--GO

--
--READ COMMITTED
--

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

BEGIN TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
GO

----CONNECTION B
--INSERT INTO Art.Artist(ArtistId, Name)
--VALUES (7, 'McCartney');
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
GO

----CONNECTION B
--UPDATE Art.Artist SET Name = 'Starr' WHERE ArtistId = 7;
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
COMMIT TRANSACTION;
GO

--
--REPEADABLE READ
--

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

BEGIN TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId >= 6;
GO

----CONNECTION B
--INSERT INTO Art.Artist(ArtistId, Name)
--VALUES (8, 'McCartney');
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId >= 6;
GO

----CONNECTION B
--DELETE Art.Artist
--WHERE  ArtistId = 6;
--GO

--CONNECTION A
COMMIT;
GO

--
--SERIALIZABLE
--

SELECT *
FROM Art.Artist;
GO

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B
--INSERT INTO Art.Artist(ArtistId, Name)
--VALUES (9, 'Vuurmann'); 
--GO

--CONNECTION A
COMMIT TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist;

----------------------------------------------------------------------------------------------------------
--Interesting Cases
----------------------------------------------------------------------------------------------------------

--
--Locking and Foreign Keys
--

--CONNECTION A
BEGIN TRANSACTION;
INSERT INTO Art.ArtWork(ArtWorkId, ArtistId, Name)
VALUES (4,9,'Revolver Album Cover');
GO

----CONNECTION B
--DELETE FROM Art.Artist WHERE ArtistId = 9;
--GO

-- CONNECTION A
COMMIT TRANSACTION;
GO

--CONNECTION A
BEGIN TRANSACTION;
INSERT INTO Art.ArtWork(ArtWorkId, ArtistId, Name)
VALUES (5,9,'Liverpool Rascals');
GO

----CONNECTION B
--UPDATE Art.Artist
--SET  Name = 'Voorman'
--WHERE ArtistId = 9;
--GO

--CONNECTION A
ROLLBACK TRANSACTION;
SELECT * FROM Art.Artwork WHERE ArtistId = 9;
GO

--
--Application Locks
--

--CONNECTION A

BEGIN TRANSACTION;
   DECLARE @result int;
   EXEC @result = sp_getapplock @Resource = 'InvoiceId=1', 
                                @LockMode = 'Exclusive';
   SELECT @result;
GO

--first parameter is a database principal, in this case public
SELECT APPLOCK_MODE('public','InvoiceId=1'); 
GO

----CONNECTION B
--BEGIN TRANSACTION;
--   DECLARE @result int;
--   EXEC @result = sp_getapplock @Resource = 'InvoiceId=1', 
--                                @LockMode = 'Exclusive';
--   SELECT @result;
--GO

----cancel the transaction

----CONNECTION B
--BEGIN TRANSACTION;
--SELECT  APPLOCK_TEST('Public','InvoiceId=1','Exclusive','Transaction') 
--                                                           AS CanTakeLock
--ROLLBACK TRANSACTION;
--GO


CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.Applock
(
    ApplockId int CONSTRAINT PKApplock PRIMARY KEY,  
                           --the value that we will be generating 
                           --with the procedure
    ConnectionId int,      --holds the spid of the connection so you can 
                           --who creates the row

    --the time the row was created, so you can see the progression
    InsertTime datetime2(3) DEFAULT (SYSDATETIME()) 
    
);
GO

CREATE OR ALTER PROCEDURE Demo.Applock$Test
(
    @ConnectionId int,
    @UseApplockFlag bit = 1,
    @StepDelay varchar(10) = '00:00:00'
) AS
SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;
        DECLARE @retval int = 1;
        IF @UseApplockFlag = 1 --turns on and off the applock for testing
            BEGIN
                EXEC @retval = sp_getAppLock @Resource = 'applock$test', 
                                             @LockMode = 'exclusive'; 
                IF @retval < 0 
                    BEGIN
                        DECLARE @errorMessage nvarchar(200);
                        SET @errorMessage = 
                            CASE @retval
                              WHEN -1 THEN 'Applock request timed out.'
                              WHEN -2 THEN 'Applock request canceled.'
                              WHEN -3 THEN 'Applock involved in deadlock'
                              ELSE 'Parameter validation or other error.'
                             END;
                        THROW 50000,@errorMessage,16;
                    END;
            END;

    --get the next primary key value. Add 1. Don’t let value end in zero
    --for demo reasons. The real need can be a lot more complex
    DECLARE @ApplockId int;   
    SET @ApplockId = COALESCE((SELECT MAX(ApplockId) FROM Demo.Applock),0) 
                                                                       + 1;
    IF @ApplockId % 10 = 0 SET @ApplockId = @ApplockId + 1;
    --delay for parameterized amount of time to slow down operations 
    --and guarantee concurrency problems
    WAITFOR DELAY @stepDelay; 

    --insert the next value
    INSERT INTO Demo.Applock(ApplockId, connectionId)
    VALUES (@ApplockId, @ConnectionId); 

    --won't have much effect on this code, since the row will now be 
    --exclusively locked, and the max will need to see the new row to 
    --be of any effect.

    IF @useApplockFlag = 1 --turns on and off the applock for testing
        EXEC @retval = sp_releaseApplock @Resource = 'applock$test'; 

    --this releases the applock too
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    --if there is an error, roll back and display it.
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    SELECT CAST(ERROR_NUMBER() as varchar(10)) + ':' + ERROR_MESSAGE();
END CATCH; 
GO


--CONNECTION A
--test on multiple connections
WAITFOR TIME '16:30';  --set for a time to run so multiple batches 
                       --can simultaneously execute
GO
IF @@TRANCOUNT > 0 ROLLBACK;
GO
EXEC Demo.Applock$Test @connectionId = @@spid
          ,@useApplockFlag = 1 -- <1=use applock, 0 = don't use applock>
          ,@stepDelay = '00:00:00.001';
          --'delay in hours:minutes:seconds.parts of seconds'
GO 10000 --runs the batch 10000 times in SSMS

----------------------------------------------------------------------------------------------------------
--Why Exclusive Locks Aren't Always Exclusive
----------------------------------------------------------------------------------------------------------

--Connection A
BEGIN TRANSACTION
SELECT *
FROM  Art.Artist WITH (XLOCK)
GO

----Connection B
--SELECT Name
--FROM   Art.Artist
--WHERE  ArtistId = 1
--GO

--Connection A
UPDATE Art.Artist
SET   Name = 'Dah Vinci'
WHERE  Artist.ArtistId = 1;
GO

----Connection B
--SELECT Name
--FROM   Art.Artist
--WHERE  ArtistId = 1
--GO


--Connection A
ROLLBACK; --Close the transaction
BEGIN TRANSACTION --Start another one
SELECT *
FROM  Art.Artist WITH (XLOCK) --exclusively lock the rows again
GO

----Connection B
--SELECT Name
--FROM   Art.Artist
--WHERE  ArtistId = 1
--GO

--cancel blocked transaction

--CONNECTION B
--CHECKPOINT;
--GO

----Connection B
--SELECT Name
--FROM   Art.Artist
--WHERE  ArtistId = 1
--GO

--CONNECTION A
ROLLBACK;

----------------------------------------------------------------------------------------------------------
--*****
--Optimistic Concurrency Enforcement
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Optimistic Concurrency Enforcement in On-Disk Tables
----------------------------------------------------------------------------------------------------------

--
--SNAPSHOT Isolation Level
--

ALTER DATABASE Chapter12
     SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B
--INSERT INTO Art.Artist(ArtistId, Name)
--VALUES (10, 'Disney');
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B
--DELETE FROM Art.Artist
--WHERE  ArtistId = 3;
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist;
GO

--CONNECTION A
COMMIT TRANSACTION
SELECT ArtistId, Name FROM Art.Artist;
GO


--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;

UPDATE Art.Artist
SET    Name = 'Duh Vinci'
WHERE  ArtistId = 1;

ROLLBACK;
GO

----CONNECTION B
--BEGIN TRANSACTION

--UPDATE Art.Artist
--SET    Name = 'Dah Vinci'
--WHERE  ArtistId = 1;
--GO

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

UPDATE Art.Artist
SET    Name = 'Duh Vinci'
WHERE  ArtistId = 1;
GO

--CONNECTION B
--ROLLBACK;
GO


--CONNECTION A
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
SELECT *
FROM   Art.Artist;
GO

----CONNECTION B
--UPDATE Art.Artist
--SET    Name = 'Dah Vinci'
--WHERE  ArtistId = 1;
--GO

--causes error
--CONNECTION A
UPDATE Art.Artist
SET    Name = 'Duh Vinci'
WHERE  ArtistId = 1;
GO

--
--READ COMMITTED SNAPSHOT (Database Setting)
--

--must be no active connections other than the connection executing
--this ALTER command
ALTER DATABASE Chapter12
    SET READ_COMMITTED_SNAPSHOT ON;
GO

ALTER DATABASE Chapter12
    SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

--CONNECTION A
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B
--BEGIN TRANSACTION;
--INSERT INTO Art.Artist (ArtistId, Name)
--VALUES  (11, 'Freling');
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B (still in a transaction)
--UPDATE Art.Artist 
--SET  Name = UPPER(Name);
--GO

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist;
GO

----CONNECTION B
--COMMIT;

--CONNECTION A
SELECT ArtistId, Name FROM Art.Artist;
GO

--CONNECTION A
COMMIT TRANSACTION;
GO

----------------------------------------------------------------------------------------------------------
--Optimistic Concurrency Enforcement in Memory Optimized Tables
----------------------------------------------------------------------------------------------------------
ALTER DATABASE Chapter12 ADD FILEGROUP [MemoryOptimizedFG] 
                                     CONTAINS MEMORY_OPTIMIZED_DATA; 
ALTER DATABASE Chapter12
ADD FILE
(
   NAME= N'Chapter13_inmemFiles',
   --note, use a drive of your choice. Ideally not C: in production 
   FILENAME = N'C:\temp\Chapter13InMemfiles'
)  
TO FILEGROUP [MemoryOptimizedFG];
GO

CREATE SCHEMA Art_InMem;
GO
CREATE TABLE Art_InMem.Artist
(
    ArtistId int CONSTRAINT PKArtist PRIMARY KEY  
                         NONCLUSTERED HASH  WITH (BUCKET_COUNT=100)

     --no key on value for demo purposes, just like on-disk example
    ,Name varchar(30) 
     --can't use REPLICATE in memory optimized table, so will use in INSERT
    ,Padding char(4000) 

) WITH ( MEMORY_OPTIMIZED = ON ); 

INSERT INTO Art_InMem.Artist(ArtistId, Name,Padding)
VALUES (1,'da Vinci',REPLICATE('a',4000)),
       (2,'Micheangelo',REPLICATE('a',4000)), 
       (3,'Donatello',REPLICATE('a',4000)),
       (4,'Picasso',REPLICATE('a',4000)),
       (5,'Dali',REPLICATE('a',4000)), 
       (6,'Jones',REPLICATE('a',4000));     
GO

CREATE TABLE Art_InMem.ArtWork
(
    ArtWorkId int CONSTRAINT PKArtWork PRIMARY KEY 
                         NONCLUSTERED HASH  WITH (BUCKET_COUNT=100)
    ,ArtistId int NOT NULL 
        CONSTRAINT FKArtwork$wasDoneBy$Art_Artist 
                             REFERENCES Art_InMem.Artist (ArtistId)
    ,Name varchar(30) 
    ,Padding char(4000) 
    ,CONSTRAINT AKArtwork UNIQUE NONCLUSTERED (ArtistId, Name)
) WITH ( MEMORY_OPTIMIZED = ON ); 

INSERT Art_InMem.Artwork (ArtworkId, ArtistId, Name,Padding)
VALUES (1,1,'Last Supper',REPLICATE('a',4000)),
       (2,1,'Mona Lisa',REPLICATE('a',4000)),
       (3,6,'Rabbit Fire',REPLICATE('a',4000));
GO

SELECT ArtistId, Name
FROM   Art_Inmem.Artist;
GO

--causes error
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM   Art_Inmem.Artist;
COMMIT TRANSACTION;
GO

ALTER DATABASE Chapter12
	SET MEMORY_OPTIMIZED_ELEVATE_TO_SNAPSHOT ON;
GO

--causes error
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM   Art_Inmem.Artist WITH (REPEATABLEREAD);
COMMIT TRANSACTION;
GO


--
--SNAPSHOT Isolation Leve
--

--CONNECTION A
BEGIN TRANSACTION;
GO

----CONNECTION B
--INSERT INTO Art_InMem.Artist(ArtistId, Name)
--VALUES (7, 'McCartney');
--GO

--CONNECTION A
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 5;
GO

----CONNECTION B
--INSERT INTO Art_InMem.Artist(ArtistId, Name)
--VALUES (8, 'Starr');

--INSERT INTO Art_InMem.Artwork(ArtworkId, ArtistId, Name)
--VALUES (4,7,'The Kiss');

--DELETE FROM Art_InMem.Artist WHERE ArtistId = 5;
--GO

--CONNECTION A
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 5;

SELECT COUNT(*)
FROM  Art_InMem.Artwork WITH (SNAPSHOT);
GO

--CONNECTION A
COMMIT;

SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 5;

SELECT COUNT(*)
FROM  Art_InMem.Artwork WITH (SNAPSHOT);
GO

--
--REPEATABLE READ Isolation Level
--

SET TRAN ISOLATION LEVEL READ COMMITTED;
--CONNECTION A
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (REPEATABLEREAD)
WHERE ArtistId >= 8;
GO

----CONNECTION B
--INSERT INTO Art_InMem.Artist(ArtistId, Name)
--VALUES (9,'Groening'); 

--CONNECTION A
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 8;
COMMIT;

SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 8;
GO

--CONNECTION A
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (REPEATABLEREAD)
WHERE ArtistId >= 8;
GO

----CONNECTION B
--DELETE FROM Art_InMem.Artist WHERE ArtistId = 9; --Nothing against Matt!
--GO


--CONNECTION A
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 8;
COMMIT;

SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 8;

--
--SERIALIZABLE Isolation Level
--

--CONNECTION A
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SERIALIZABLE)
WHERE ArtistId >= 8;
GO

----CONNECTION B
--INSERT INTO Art_InMem.Artist(ArtistId, Name)
--VALUES (9,'Groening'); --See, brought him back!
--GO

--CONNECTION A
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId >= 8;
COMMIT;
GO


--CONNECTION A
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SERIALIZABLE)
WHERE Name = 'Starr';

----CONNECTION B
--UPDATE Art_InMem.Artist WITH (SNAPSHOT) 
--     --default to snapshot, but the change itself
--     --behaves the same in any isolation level
--SET    Padding = REPLICATE('a',4000) --just make a change
--WHERE  Name = 'McCartney'; 
--GO

--causes error
--CONNECTION A
COMMIT;
GO

ALTER TABLE Art_InMem.Artist
  ADD CONSTRAINT AKArtist UNIQUE NONCLUSTERED (Name) --A string column may    
                  --be used to do ordered scans,particularly one like name
GO

--CONNECTION A
BEGIN TRANSACTION;
SELECT ArtistId, Name
FROM  Art_InMem.Artist WITH (SERIALIZABLE)
WHERE Name = 'Starr';

----CONNECTION B
--UPDATE Art_InMem.Artist WITH (SNAPSHOT) 
--     --default to snapshot, but the change itself
--     --behaves the same in any isolation level
--SET    Padding = REPLICATE('a',4000) --just make a change
--WHERE  Name = 'McCartney'; 
--GO

--no error with the index in place
--CONNECTION A
COMMIT;
GO

--
--Write Contention
--

--Two users delete the same row


--CONNECTION A
BEGIN TRANSACTION;
UPDATE Art_InMem.Artist WITH (SNAPSHOT)
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE  Name = 'McCartney'; 
GO

--causes immediate error
--CONNECTION B
BEGIN TRANSACTION;
UPDATE Art_InMem.Artist WITH (SNAPSHOT)
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE  Name = 'McCartney'; 
GO

--CONNECTION A
ROLLBACK;
GO

--Two users insert a row with uniqueness collision

--CONNECTION A
ROLLBACK TRANSACTION --from previous example, with unique index on Name

BEGIN TRANSACTION
INSERT INTO Art_InMem.Artist (ArtistId, Name)
VALUES  (11,'Wright');

--CONNECTION A
COMMIT;
GO

----CONNECTION B
--COMMIT;
--GO

--One user inserts a row that would collide with a deleted row

--CONNECTION A
BEGIN TRANSACTION;
DELETE FROM Art_InMem.Artist WITH (SNAPSHOT)
WHERE ArtistId = 4;
GO

----CONNECTION B same effect in or out of transaction, but transaction
----but transaction used later               
--BEGIN TRANSACTION;
--INSERT INTO Art_InMem.Artist (ArtistId, Name)
--VALUES (4,'Picasso');
--GO

--CONNECTION A
COMMIT;
GO

----CONNECTION B
--INSERT INTO Art_InMem.Artist (ArtistId, Name)
--VALUES (4,'Picasso');
--GO

----CONNECTION B
--COMMIT
--GO

--
--Foreign Keys
--

--CONNECTION A
BEGIN TRANSACTION
INSERT INTO Art_InMem.Artwork(ArtworkId, ArtistId, Name)
VALUES (5,4,'The Old Guitarist');
GO

----CONNECTION B
--UPDATE Art_InMem.Artist WITH (SNAPSHOT)
--SET    Padding = REPLICATE('a',4000) --just make a change
--WHERE ArtistId = 4;
--GO

--CONNECTION A
COMMIT;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Coding for Asynchronous Contention
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Hr;
GO
CREATE TABLE Hr.person
(
     PersonId int IDENTITY(1,1) CONSTRAINT PKPerson PRIMARY KEY,
     FirstName varchar(60) NOT NULL,
     MiddleName varchar(60) NOT NULL,
     LastName varchar(60) NOT NULL,

     DateOfBirth date NOT NULL,
     RowLastModifyTime datetime2(3) NOT NULL
         CONSTRAINT DFLTPerson_RowLastModifyTime DEFAULT (SYSDATETIME()),
     RowModifiedByUserIdentifier nvarchar(128) NOT NULL
         CONSTRAINT DFLTPerson_RowModifiedByUserIdentifier 
                                                DEFAULT (SUSER_SNAME())
);
GO
CREATE TRIGGER Hr.Person$InsteadOfUpdateTrigger
ON Hr.Person
INSTEAD OF UPDATE AS
BEGIN

    --stores the number of rows affected
   DECLARE @rowsAffected int = @@rowcount,
           @msg varchar(2000) = '';    --used to hold the error message

      --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --remember to update ALL columns when building instead 
          --instead of triggers
          UPDATE Hr.Person
          SET    FirstName = inserted.FirstName,
                 MiddleName = inserted.MiddleName,
                 LastName = inserted.LastName,
                 DateOfBirth = inserted.DateOfBirth,
                 -- set the values to the default
                 RowLastModifyTime = DEFAULT, -- set the value to the default
                 RowModifiedByUserIdentifier = DEFAULT 
          FROM   Hr.Person                              
                     JOIN inserted
                             ON Person.PersonId = inserted.PersonId;
   END TRY
      BEGIN CATCH
              IF XACT_STATE() > 0
                  ROLLBACK TRANSACTION;

              THROW; --will halt the batch or be caught by the caller's catch block

     END CATCH;
END;
GO

INSERT INTO Hr.Person (FirstName, MiddleName, LastName, DateOfBirth)
VALUES ('Paige','O','Anxtent','19691212');

SELECT *
FROM   Hr.Person;
GO

UPDATE Hr.Person
SET    MiddleName = 'Ona'
WHERE  PersonId = 1;

SELECT @@ROWCOUNT as RowsAffected --if 0, then throw error to retry

SELECT RowLastModifyTime
FROM   Hr.Person;
GO


ALTER TABLE Hr.person
     ADD RowVersion rowversion;
GO
SELECT PersonId, RowVersion
FROM   Hr.Person;
GO


UPDATE  Hr.Person
SET     FirstName = 'Paige' --no actual change occurs
WHERE   PersonId = 1
GO

SELECT PersonId, RowVersion
FROM   Hr.Person;
GO

----------------------------------------------------------------------------------------------------------
--Coding for Row-Level Change Detection
----------------------------------------------------------------------------------------------------------


UPDATE  Hr.Person
SET     FirstName = 'Headley'
WHERE   PersonId = 1  
  --include the key, even when changing the key value if allowed
  --non-key columns
  and   FirstName = 'Paige' --Note, when columns allow NULL values, must
  and   MiddleName = 'ona'  --take extra precautions if using compiled code
  and   LastName = 'Anxtent'
  and   DateOfBirth = '19691212';
GO

UPDATE  Hr.Person
SET     FirstName = 'Fred'
WHERE   PersonId = 1  --include the key
  AND   RowLastModifyTime = '2020-06-18 23:09:12.453' --your date will be different!
GO

UPDATE  Hr.Person
SET     FirstName = 'Fred'
WHERE   PersonId = 1
  and   RowVersion = 0x00000000000007D4;
GO

DELETE FROM Hr.Person
WHERE  PersonId = 1
  And  Rowversion = 0x00000000000007D5;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Coding for Logical Unit of Work Change Detection
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Invoicing;
GO
--leaving off who invoice is for, like an account or person name
CREATE TABLE Invoicing.Invoice
(
     InvoiceId int IDENTITY(1,1),
     Number varchar(20) NOT NULL,
     ObjectVersion rowversion NOT NULL,
     CONSTRAINT PKInvoice PRIMARY KEY (InvoiceId)
);
--also ignoring what product that the line item is for
CREATE TABLE Invoicing.InvoiceLineItem

(
     InvoiceLineItemId int NOT NULL,
     InvoiceId int NOT NULL,
     ItemCount int NOT NULL,
     CostAmount int NOT NULL,
     CONSTRAINT PKInvoiceLineItem primary key (InvoiceLineItemId),
     CONSTRAINT FKInvoiceLineItem$references$Invoicing_Invoice
            FOREIGN KEY (InvoiceId) REFERENCES Invoicing.Invoice(InvoiceId)
);
GO

CREATE PROCEDURE InvoiceLineItem$Delete
(
    @InvoiceId int, --we pass this because the client should have it
                    --with the invoiceLineItem row
    @InvoiceLineItemId int,
    @ObjectVersion rowversion
) as
  BEGIN
    --gives us a unique savepoint name, trim it to 125
    --characters if the user named it really large
    DECLARE @savepoint nvarchar(128) = 
                          CAST(OBJECT_NAME(@@procid) AS nvarchar(125)) +
                                         CAST(@@nestlevel AS nvarchar(3));
    --get initial entry level, so we can do a rollback on a doomed transaction
    DECLARE @entryTrancount int = @@trancount;

    BEGIN TRY
        BEGIN TRANSACTION;
        SAVE TRANSACTION @savepoint;


        --tweak the ObjectVersion on the Invoice Table
        UPDATE  Invoicing.Invoice
        SET     Number = Number
        WHERE   InvoiceId = @InvoiceId
          And   ObjectVersion = @ObjectVersion;

        IF @@ROWCOUNT = 0
          BEGIN
           IF NOT EXISTS ( SELECT *
                           FROM   Invoicing.Invoice
                           WHERE  InvoiceId = 1) 
           THROW 50000,'The InvoiceId has been deleted',1;
          ELSE
           THROW 50000,'The InvoiceId has been changed',1;
		  
           
        DELETE  Invoicing.InvoiceLineItem
        FROM    InvoiceLineItem
        WHERE   InvoiceLineItemId = @InvoiceLineItemId;

        COMMIT TRANSACTION;
      END
    END TRY
     BEGIN CATCH
           IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

           --will halt the batch or be caught by the caller's catch block
           THROW; 
     END CATCH;
 END;
 GO