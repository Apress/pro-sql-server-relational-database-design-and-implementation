
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
--
--READ UNCOMMITTED
--

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED; --this is the default, just 
--                                                --setting for emphasis
--BEGIN TRANSACTION;
--INSERT INTO Art.Artist(ArtistId, Name)
--VALUES (7, 'McCartney');

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT ArtistId, Name
FROM Art.Artist
WHERE Name = 'McCartney';
GO

--Stop the transaction that is blocked

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT ArtistId, Name
FROM Art.Artist
WHERE Name = 'McCartney';

----CONNECTION A
--ROLLBACK TRANSACTION;

--CONNECTION B
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT ArtistId, Name
FROM Art.Artist
WHERE Name = 'McCartney';

--
--READ COMMITTED
--
----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

--BEGIN TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
--GO

--CONNECTION B
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (7, 'McCartney');
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
--GO

--CONNECTION B
UPDATE Art.Artist SET Name = 'Starr' WHERE ArtistId = 7;
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId = 7;
--COMMIT TRANSACTION;
--GO

--
--REPEADABLE READ
--

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

--BEGIN TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId >= 6;
--GO

--CONNECTION B
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (8, 'McCartney');
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist WHERE ArtistId >= 6;
--GO

--CONNECTION B
DELETE Art.Artist
WHERE  ArtistId = 6;
GO

----CONNECTION A
--COMMIT;
--GO


--
--SERIALIZABLE
--

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

--BEGIN TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (9, 'Vuurmann'); 
GO

----CONNECTION A
--COMMIT TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist;
--GO

----------------------------------------------------------------------------------------------------------
--Interesting Cases
----------------------------------------------------------------------------------------------------------


--
--Locking and Foreign Keys
--

----CONNECTION A
--BEGIN TRANSACTION;
--INSERT INTO Art.ArtWork(ArtWorkId, ArtistId, Name)
--VALUES (4,9,'Revolver Album Cover');
--GO

--CONNECTION B
DELETE FROM Art.Artist WHERE ArtistId = 9;
GO

---- CONNECTION A
--COMMIT TRANSACTION;
--GO

----CONNECTION A
--BEGIN TRANSACTION;
--INSERT INTO Art.ArtWork(ArtWorkId, ArtistId, Name)
--VALUES (5,9,'Liverpool Rascals');
--GO

--CONNECTION B
UPDATE Art.Artist
SET  Name = 'Voorman'
WHERE ArtistId = 9;
GO

----CONNECTION A
--ROLLBACK TRANSACTION;
--SELECT * FROM Art.Artwork WHERE ArtistId = 9;

--
--Application Locks
--

----CONNECTION A

--BEGIN TRANSACTION;
--   DECLARE @result int;
--   EXEC @result = sp_getapplock @Resource = 'InvoiceId=1', 
--                                @LockMode = 'Exclusive';
--   SELECT @result;
--GO


--CONNECTION B
BEGIN TRANSACTION;
   DECLARE @result int;
   EXEC @result = sp_getapplock @Resource = 'InvoiceId=1', 
                                @LockMode = 'Exclusive';
   SELECT @result;
GO

--cancel the transaction

--CONNECTION B
BEGIN TRANSACTION;
SELECT  APPLOCK_TEST('Public','InvoiceId=1','Exclusive','Transaction') 
                                                           AS CanTakeLock
ROLLBACK TRANSACTION;
GO


--CONNECTION B
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
----Connection A
--BEGIN TRANSACTION
--SELECT *
--FROM  Art.Artist WITH (XLOCK)
--GO

--Connection B
SELECT Name
FROM   Art.Artist
WHERE  ArtistId = 1
GO

----Connection A
--UPDATE Art.Artist
--SET   Name = Artist.Name
--WHERE  Artist.ArtistId = 1;
--GO

--Connection B
SELECT Name
FROM   Art.Artist
WHERE  ArtistId = 1
GO


----Connection A
--ROLLBACK; --Close the transaction
--BEGIN TRANSACTION --Start another one
--SELECT *
--FROM  Art.Artist WITH (XLOCK) --exclusively lock the rows again
--GO

--Connection B
SELECT Name
FROM   Art.Artist
WHERE  ArtistId = 1
GO

--cancel blocked transaction

--CONNECTION B
CHECKPOINT;
GO

--Connection B
SELECT Name
FROM   Art.Artist
WHERE  ArtistId = 1
GO

--CONNECTION A
--ROLLBACK;
--GO


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

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
--BEGIN TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B
INSERT INTO Art.Artist(ArtistId, Name)
VALUES (10, 'Disney');
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B
DELETE FROM Art.Artist
WHERE  ArtistId = 3;
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist;
--GO

----CONNECTION A
--COMMIT TRANSACTION
--SELECT ArtistId, Name FROM Art.Artist;
--GO

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
--BEGIN TRANSACTION;

--UPDATE Art.Artist
--SET    Name = 'Duh Vinci'
--WHERE  ArtistId = 1;

--ROLLBACK;
--GO

--CONNECTION B
BEGIN TRANSACTION

UPDATE Art.Artist
SET    Name = 'Dah Vinci'
WHERE  ArtistId = 1;
GO

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL SNAPSHOT;

--UPDATE Art.Artist
--SET    Name = 'Duh Vinci'
--WHERE  ArtistId = 1;

--CONNECTION B
ROLLBACK;
GO



----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
--BEGIN TRANSACTION;
--SELECT *
--FROM   Art.Artist;
--GO

--CONNECTION B
UPDATE Art.Artist
SET    Name = 'Dah Vinci'
WHERE  ArtistId = 1;
GO

----CONNECTION A
--UPDATE Art.Artist
--SET    Name = 'Duh Vinci'
--WHERE  ArtistId = 1;
--GO

--
--READ COMMITTED SNAPSHOT (Database Setting)
--

----CONNECTION A
--SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
--BEGIN TRANSACTION;
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B
BEGIN TRANSACTION;
INSERT INTO Art.Artist (ArtistId, Name)
VALUES  (11, 'Freling');
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B (still in a transaction)
UPDATE Art.Artist 
SET  Name = UPPER(Name);
GO

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist;
--GO

--CONNECTION B
COMMIT;

----CONNECTION A
--SELECT ArtistId, Name FROM Art.Artist;
--GO

----CONNECTION A
--COMMIT TRANSACTION;
--GO

----------------------------------------------------------------------------------------------------------
--Optimistic Concurrency Enforcement in Memory Optimized Tables
----------------------------------------------------------------------------------------------------------

--
--SNAPSHOT Isolation Leve
--

----CONNECTION A
--BEGIN TRANSACTION;
--GO

--CONNECTION B
INSERT INTO Art_InMem.Artist(ArtistId, Name)
VALUES (7, 'McCartney');
GO

----CONNECTION A
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 5;
--GO

--CONNECTION B
INSERT INTO Art_InMem.Artist(ArtistId, Name)
VALUES (8, 'Starr');

INSERT INTO Art_InMem.Artwork(ArtworkId, ArtistId, Name)
VALUES (4,7,'The Kiss');

DELETE FROM Art_InMem.Artist WHERE ArtistId = 5;
GO

----CONNECTION A
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 5;

--SELECT COUNT(*)
--FROM  Art_InMem.Artwork WITH (SNAPSHOT);
--GO

----CONNECTION A
--COMMIT;

--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 5;

--SELECT COUNT(*)
--FROM  Art_InMem.Artwork WITH (SNAPSHOT);
--GO

--
--REPEATABLE READ Isolation Level
--


--SET TRAN ISOLATION LEVEL READ COMMITTED;
----CONNECTION A
--BEGIN TRANSACTION;
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (REPEATABLEREAD)
--WHERE ArtistId >= 8;
--GO

--CONNECTION B
INSERT INTO Art_InMem.Artist(ArtistId, Name)
VALUES (9,'Groening'); 
GO

----CONNECTION A
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 8;
--COMMIT;

--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 8;
--GO

----CONNECTION A
--BEGIN TRANSACTION;
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (REPEATABLEREAD)
--WHERE ArtistId >= 8;
--GO


--CONNECTION B
DELETE FROM Art_InMem.Artist WHERE ArtistId = 9; --Nothing against Matt!
GO

----CONNECTION A
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 8;
--COMMIT;

--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 8;


--
--SERIALIZABLE Isolation Level
--

----CONNECTION A
--BEGIN TRANSACTION;
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SERIALIZABLE)
--WHERE ArtistId >= 8;
--GO

--CONNECTION B
INSERT INTO Art_InMem.Artist(ArtistId, Name)
VALUES (9,'Groening'); --See, brought him back!
GO

----CONNECTION A
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId >= 8;
--COMMIT;
--GO


----CONNECTION A
--BEGIN TRANSACTION;
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SERIALIZABLE)
--WHERE Name = 'Starr';
--GO

--CONNECTION B
UPDATE Art_InMem.Artist WITH (SNAPSHOT) 
     --default to snapshot, but the change itself
     --behaves the same in any isolation level
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE  Name = 'McCartney'; 
GO

----CONNECTION A
--COMMIT;
--GO


----CONNECTION A
--BEGIN TRANSACTION;
--SELECT ArtistId, Name
--FROM  Art_InMem.Artist WITH (SERIALIZABLE)
--WHERE Name = 'Starr';
--GO

--CONNECTION B
UPDATE Art_InMem.Artist WITH (SNAPSHOT) 
     --default to snapshot, but the change itself
     --behaves the same in any isolation level
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE  Name = 'McCartney'; 
GO

----CONNECTION A
--COMMIT;
--GO


--
--Write Contention
--

--Two users delete the same row

----CONNECTION A
--BEGIN TRANSACTION;
--UPDATE Art_InMem.Artist WITH (SNAPSHOT)
--SET    Padding = REPLICATE('a',4000) --just make a change
--WHERE  Name = 'McCartney'; 

--causes immediate error
--CONNECTION B
BEGIN TRANSACTION;
UPDATE Art_InMem.Artist WITH (SNAPSHOT)
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE  Name = 'McCartney'; 
GO

----CONNECTION A
--ROLLBACK;
--GO


--Two users insert a row with uniqueness collision

----CONNECTION A
--ROLLBACK TRANSACTION --from previous example, with unique index on Name

--BEGIN TRANSACTION
--INSERT INTO Art_InMem.Artist (ArtistId, Name)
--VALUES  (11,'Wright');
--GO

--CONNECTION B
BEGIN TRANSACTION;
INSERT INTO Art_InMem.Artist (ArtistId, Name)
VALUES  (11,'Wright');

----CONNECTION A
--COMMIT;
--GO

--CONNECTION B
COMMIT;
GO

--One user inserts a row that would collide with a deleted row

----CONNECTION A
--BEGIN TRANSACTION;
--DELETE FROM Art_InMem.Artist WITH (SNAPSHOT)
--WHERE ArtistId = 4;
--GO

--CONNECTION B same effect in or out of transaction, but transaction
--but transaction used later               
BEGIN TRANSACTION;
INSERT INTO Art_InMem.Artist (ArtistId, Name)
VALUES (4,'Picasso');
GO

----CONNECTION A
--COMMIT;
--GO

--CONNECTION B
INSERT INTO Art_InMem.Artist (ArtistId, Name)
VALUES (4,'Picasso');
GO

--CONNECTION B
COMMIT
GO

--CONNECTION B
INSERT INTO Art_InMem.Artist (ArtistId, Name)
VALUES (4,'Picasso');--We like Picasso

--
--Foreign Keys
--

----CONNECTION A
--BEGIN TRANSACTION
--INSERT INTO Art_InMem.Artwork(ArtworkId, ArtistId, Name)
--VALUES (5,4,'The Old Guitarist');
--GO

--CONNECTION B
UPDATE Art_InMem.Artist WITH (SNAPSHOT)
SET    Padding = REPLICATE('a',4000) --just make a change
WHERE ArtistId = 4;
GO

----CONNECTION A
--COMMIT;
--GO


