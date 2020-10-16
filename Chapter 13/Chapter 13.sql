--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
EXIT

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Building the data access layer
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Using Ad Hoc SQL
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Ad Hoc SQL Advantages
----------------------------------------------------------------------------------------------------------

--
--Runtime Control Over Queries
--

CREATE DATABASE Chapter13;
GO

CREATE SCHEMA Sales;
GO
CREATE TABLE Sales.Contact
(
    ContactId   int NOT NULL CONSTRAINT PKContact PRIMARY KEY,
    FirstName   varchar(30) NOT NULL,
    LastName    varchar(30) NOT NULL,
    CompanyName varchar(100) NOT NULL,
    SalesLevelId  int NOT NULL, --real table would implement 
                                --as a foreign key
    ContactNotes  varchar(max) NULL,
    CONSTRAINT AKContact UNIQUE (FirstName, LastName, CompanyName)
);
--a few rows to show some output from queries
INSERT INTO Sales.Contact
            (ContactId, FirstName, Lastname, CompanyName, SaleslevelId, ContactNotes)
VALUES( 1,'Drue','Karry','SeeBeeEss',1, 
           REPLICATE ('Blah...',10) + 'Called and discussed new ideas'),
      ( 2,'Jon','Rettre','Daughter Inc',2,
           REPLICATE ('Yada...',10) + 'Called, but he had passed on');
GO

SELECT  ContactId, FirstName, LastName, CompanyName, 
        RIGHT(ContactNotes,28) as NotesEnd
FROM    Sales.Contact;
GO

SELECT ContactId, FirstName, LastName, CompanyName 
FROM Sales.Contact;
GO

CREATE TABLE Sales.Purchase
(
    PurchaseId int  NOT NULL CONSTRAINT PKPurchase PRIMARY KEY,
    Amount numeric(10,2) NOT NULL,
    PurchaseDate date NOT NULL,
    ContactId   int NOT NULL
        CONSTRAINT FKContact$hasPurchasesIn$Sales_Purchase
            REFERENCES Sales.Contact(ContactId)
);
INSERT INTO Sales.Purchase(PurchaseId, Amount, PurchaseDate, ContactId)
VALUES (1,100.00,'2020-05-12',1),(2,200.00,'2020-05-10',1),
       (3,100.00,'2020-05-12',2),(4,300.00,'2020-05-12',1),
       (5,100.00,'2020-04-11',1),(6,5500.00,'2020-05-14',2),
       (7,100.00,'2020-04-01',1),(8,1020.00,'2020-06-03',2);
GO

SELECT  Contact.ContactId, Contact.FirstName, Contact.LastName
        ,Sales.YearToDateSales, Sales.LastSaleDate
FROM   Sales.Contact as Contact
          LEFT OUTER JOIN
             (SELECT ContactId,
                     SUM(Amount) AS YearToDateSales,
                     MAX(PurchaseDate) AS LastSaleDate
              FROM   Sales.Purchase
              WHERE  PurchaseDate >= --the first day of the current year
                        DATEADD(day, 0, DATEDIFF(day, 0, SYSDATETIME() ) 
                          - DATEPART(dayofyear,SYSDATETIME() ) + 1)
              GROUP  by ContactId) AS sales
              ON Contact.ContactId = Sales.ContactId
WHERE   Contact.LastName like 'Rett%';
GO

SELECT  Contact.ContactId, Contact.FirstName, Contact.LastName
        --,Sales.YearToDateSales, Sales.LastSaleDate
FROM   Sales.Contact as Contact
          --LEFT OUTER JOIN
          --   (SELECT ContactId,
          --           SUM(Amount) AS YearToDateSales,
          --           MAX(PurchaseDate) AS LastSaleDate
          --    FROM   Sales.Purchase
          --    WHERE  PurchaseDate >= --the first day of the current year
          --              DATEADD(day, 0, DATEDIFF(day, 0, SYSDATETIME() ) 
          --                - DATEPART(dayofyear,SYSDATETIME() ) + 1)
          --    GROUP  by ContactId) AS sales
          --    ON Contact.ContactId = Sales.ContactId
WHERE   Contact.LastName like 'Karr%';
GO

UPDATE Sales.Contact
SET    FirstName = 'Drew',
       LastName = 'Carey',
       SalesLevelId = 1, --no change
       CompanyName = 'CBS', 
       ContactNotes = 'Blah...Blah...Blah...Blah...Blah...Blah...Blah...'         
                      + 'Blah...Called and discussed new ideas' 
WHERE ContactId = 1;
GO

UPDATE Sales.Contact
SET    FirstName = 'John',
       LastName = 'Ritter'
WHERE  ContactId = 2;
GO

SELECT FirstName, LastName, CompanyName
FROM   Sales.Contact
WHERE  FirstName LIKE 'J%'
  AND  LastName LIKE  'R%';
GO

SELECT FirstName, LastName, CompanyName
FROM   Sales.Contact
WHERE  LastName LIKE 'Carey%';
GO

--
--Shared Execution Plans

USE WideWorldImporters;
GO
SELECT People.FullName, Orders.OrderDate
FROM   Sales.Orders
                 JOIN Application.People 
                        ON Orders.ContactPersonID = People.PersonID
WHERE  People.FullName = N'Bala Dixit';
GO

SELECT People.FullName, Orders.OrderDate
FROM   Sales.Orders 
                 JOIN Application.People 
                        on Orders.ContactPersonID = People.PersonID
WHERE  People.FullName = N'Bala Dixit';
GO

SELECT  *
FROM    (SELECT qs.execution_count,
                SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1, 
                                ((CASE qs.statement_end_offset
                       WHEN -1 THEN DATALENGTH(st.text)
                       ELSE qs.statement_end_offset
               END - qs.statement_start_offset) / 2) + 1) AS statement_text
         FROM   sys.dm_exec_query_stats AS qs
                CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
        ) AS queryStats
WHERE   queryStats.statement_text 
             LIKE 'SELECT People%'
-- Note that it may take a minute or so for the queries to show up 

--
--Parameterization

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
WHERE  People.FullName = N'Bala Dixit';
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
WHERE  People.FullName = N'Vlatka Duvnjak';
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
WHERE  People.FullName = N'Not Inthetable';
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
		JOIN Application.People_Archive
			ON People.PersonID = People_Archive.PersonId
WHERE  People.FullName =N'Lily Code';
GO
SET SHOWPLAN_TEXT OFF;
GO

ALTER DATABASE WideWorldImporters
    SET PARAMETERIZATION FORCED;
GO

--I needed to disconnect and reconnect 

USE WideWorldImporters;
GO
SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
		JOIN Application.People_Archive
			ON People.PersonID = People_Archive.PersonId
WHERE  People.FullName =N'Bala Dixit';
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
		JOIN Application.People_Archive
			ON People.PersonID = People_Archive.PersonId
WHERE  People.FullName LIKE N'Lily Code';
GO
SET SHOWPLAN_TEXT OFF;
GO

SET SHOWPLAN_TEXT ON;
GO
SELECT People.FullName
FROM   Application.People 
		JOIN Application.People_Archive
			ON People.PersonID = People_Archive.PersonId
WHERE  People.FullName LIKE N'Lily Code%';
GO
SET SHOWPLAN_TEXT OFF;
GO

--Can't see the estimated plan for this query
SET STATISTICS PROFILE ON
GO
DECLARE @FullName nvarchar(60) = N'Bala Dixit',
        @Query nvarchar(500),
        @Parameters nvarchar(500)

SET @Query= N'SELECT People.FullName, Orders.OrderDate
              FROM   Sales.Orders 
                       JOIN Application.People 
                           ON Orders.ContactPersonID = People.PersonID
              WHERE  People.FullName LIKE @FullName';
SET @Parameters = N'@FullName nvarchar(60)';

EXECUTE sp_executesql @Query, @Parameters, @FullName = @FullName;
GO
SET STATISTICS PROFILE OFF
GO


DECLARE @Query nvarchar(500),
        @Parameters nvarchar(500),
        @Handle int

SET @Query= N'SELECT People.FullName, Orders.OrderDate
              FROM   Sales.Orders 
                         JOIN Application.People 
                                ON Orders.ContactPersonID = People.PersonID
              WHERE  People.FullName LIKE @FullName';
SET @Parameters = N'@FullName nvarchar(60)';

EXECUTE sp_prepare @Handle output, @Parameters, @Query;
SELECT @handle;
GO

SET STATISTICS PROFILE ON;
GO
DECLARE  @FullName nvarchar(60) = N'Bala Dixit';
EXECUTE sp_execute 1, @FullName;

SET @FullName = N'Bala%';

EXECUTE sp_execute 1, @FullName;
GO
SET STATISTICS PROFILE OFF;
GO

----------------------------------------------------------------------------------------------------------
--Ad Hoc SQL Disadvantages
----------------------------------------------------------------------------------------------------------
USE Chapter13;
--
--SQL Injection
--
DECLARE @value varchar(40) = 'Smith'; 
SELECT 'SELECT '''+ @value + '''';
EXECUTE ('SELECT '''+ @value + '''');
GO

DECLARE @value varchar(40) = 'Smith''; SELECT ''What else could I do?';
GO

CREATE SCHEMA Tools;
GO
CREATE OR ALTER FUNCTION Tools.String$EscapeString
(
	@inputString nvarchar(4000), --would work on varchar(max) too
	@character NCHAR(1) = N'''', --if you needed that
	@surroundOutputFlag bit = 1
) 
RETURNS nvarchar(4000)
AS
  BEGIN
	RETURN (CASE WHEN @surroundOutputFlag = 1 THEN @character END
	       +REPLACE(@inputString,'''','''''')
	       +CASE WHEN @surroundOutputFlag = 1 THEN @character END)
  END;
GO

DECLARE @value varchar(30) = 'O''Malley', @query nvarchar(300);
SELECT @query = 'SELECT ' + 
                       Tools.String$EscapeString(@value,DEFAULT,DEFAULT);
SELECT @query;
EXECUTE (@query );
GO


DECLARE @value varchar(40) = 'Smith''; SELECT ''What else could I do?',
        @query nvarchar(300);
SELECT @query = 'SELECT ' + 
                       Tools.String$EscapeString(@value,DEFAULT,DEFAULT);
SELECT  @query;
EXECUTE (@query);

GO


DECLARE @value varchar(30) = 'O''; SELECT ''badness',
        @query nvarchar(300),
        @parameters nvarchar(200) = N'@value varchar(30)';
SELECT @query = 'SELECT ' + 
                      Tools.String$EscapeString(@value,DEFAULT,DEFAULT);
SELECT  @query;
EXECUTE sp_executesql @Query, @Parameters, @value = @value;


----------------------------------------------------------------------------------------------------------
--*****
--Using a T-SQL coded encapsulation layer 
--*****
----------------------------------------------------------------------------------------------------------
USE WideWorldImporters;
GO


CREATE PROCEDURE Sales.Orders$Select
(
        @FullNameLike nvarchar(100) = '%',
        @OrderDateRangeStart date = '1900-01-01',
        @OrderDateRangeEnd date = '9999-12-31'
) AS
BEGIN
      SELECT People.FullName, Orders.OrderDate
      FROM   Sales.Orders 
               JOIN Application.People 
                  ON Orders.ContactPersonID = People.PersonID
      WHERE  People.FullName LIKE @FullNameLike
             --Inclusive since using Date type
        AND  OrderDate BETWEEN @OrderDateRangeStart 
                                 AND @OrderDateRangeEnd;
END;
GO

EXECUTE Sales.Orders$Select @FullNameLike = 'Bala Dixit';
GO

EXECUTE Sales.Orders$Select @FullNameLike = 'Bala Dixit', 
                    @OrderDateRangeStart = '2016-01-01',
                    @OrderDateRangeEnd = '2016-12-31';


----------------------------------------------------------------------------------------------------------
--Advantages of T-SQL Object Layers
----------------------------------------------------------------------------------------------------------

--
--Encapsulation
--

EXECUTE Sales.Orders$Select @FullNameLike = 'Bala Dixit', 
                            @OrderDateRangeStart = '2016-01-01',
                            @OrderDateRangeEnd = '2016-12-31';
GO

--Will not work if you have the plan turned on
EXECUTE sp_describe_first_result_set 
           N'Sales.Orders$Select';

GO


CREATE PROCEDURE dbo.Test (@Value int = 1)
AS 
IF @value = 1 
    SELECT 'FRED' as Name;
ELSE 
    SELECT 200 as Name;        
GO

EXECUTE sp_describe_first_result_set N'dbo.Test'

GO

--
--Dynamic Procedures
--


ALTER PROCEDURE Sales.Orders$Select
(
        @FullNameLike nvarchar(100) = '%',
        @OrderDateRangeStart date = '1900-01-01',
        @OrderDateRangeEnd date = '9999-12-31'
) AS
BEGIN
        DECLARE @query varchar(max) =
        CONCAT('
          SELECT People.FullName, Orders.OrderDate
          FROM   Sales.Orders 
                  JOIN Application.People 
                    ON Orders.ContactPersonID = People.PersonID
          WHERE  OrderDate BETWEEN ''', @OrderDateRangeStart, ''' 
                     AND ''', @OrderDateRangeEnd,'''
            AND People.FullName LIKE ''', @FullNameLike, '''' );
         SELECT @query; --for testing
         EXECUTE (@query);
END;
GO

EXECUTE Sales.Orders$Select 
           @FullNameLike = '~;''select name from sysusers--', 
           @OrderDateRangeStart = '2016-01-01';
GO

CREATE SCHEMA Tools;
GO
CREATE OR ALTER FUNCTION Tools.String$EscapeString
(
	@inputString nvarchar(4000), --would work on varchar(max) too
	@character nchar(1) = N'''', --if you needed that
	@surroundOutputFlag bit = 1
) 
RETURNS nvarchar(4000)
AS
  BEGIN
	RETURN (CASE WHEN @surroundOutputFlag = 1 THEN @character END
	       +REPLACE(@inputString,'''','''''')
	       +CASE WHEN @surroundOutputFlag = 1 THEN @character END)
  END;
GO


ALTER PROCEDURE Sales.Orders$Select
(
        @FullNameLike nvarchar(100) = '%',
        @OrderDateRangeStart date = '1900-01-01',
        @OrderDateRangeEnd date = '9999-12-31'
) AS
BEGIN
        DECLARE @query varchar(max) =
        CONCAT('
      SELECT People.FullName, Orders.OrderDate
          FROM   Sales.Orders 
                   JOIN Application.People 
                      ON Orders.ContactPersonID = People.PersonID
          WHERE  People.FullName LIKE ',    
         Tools.String$EscapeString(@FullNameLike,DEFAULT,DEFAULT), '
                AND  OrderDate BETWEEN ''', 
         @OrderDateRangeStart,''' AND ''', @OrderDateRangeEnd,'''');
         SELECT @query; --for testing
         EXECUTE (@query);
END;
GO

EXECUTE Sales.Orders$Select 
           @FullNameLike = '~;''select name from sysusers--', 
           @OrderDateRangeStart = '2016-01-01';
GO

ALTER PROCEDURE Sales.Orders$Select
(
        @FullNameLike nvarchar(100) = '%',
        @OrderDateRangeStart date = '1900-01-01',
        @OrderDateRangeEnd date = '9999-12-31'
) AS
BEGIN
        DECLARE @query varchar(max) =
        CONCAT('
          SELECT People.FullName, Orders.OrderDate
          FROM   Sales.Orders 
                   JOIN Application.People 
                      ON Orders.ContactPersonID = People.PersonID
          WHERE  1=1
          ',
           --ignore @FullNameLike parameter when it is set to all
           CASE WHEN @FullNameLike <> '%' THEN
                 CONCAT(' AND  People.FullName LIKE ',    
            Tools.String$EscapeString(@FullNameLike,DEFAULT,DEFAULT))
           ELSE '' END,
           --ignore @date parameters when it is set to all

           CASE WHEN @OrderDateRangeStart <> '1900-01-01' OR
                      @OrderDateRangeEnd <> '9999-12-31' 
                        THEN
           --note, date values do not need to be escaped, because the
           --parameter will not accept a non-date value for a value
           CONCAT('AND  OrderDate BETWEEN ''', @OrderDateRangeStart, ''' 
                                       AND ''', @OrderDateRangeEnd,'''')                        
           ELSE '' END);
          SELECT @query; --for testing
          EXECUTE (@query);
END;
GO

EXECUTE Sales.Orders$Select 
           @FullNameLike = '~;''select name from sysusers--', 
           @OrderDateRangeStart = '2016-01-01';
GO

--
--Security
--

CREATE USER Fred WITHOUT LOGIN;
GO


CREATE SCHEMA SecurityDemo;
GO
CREATE PROCEDURE SecurityDemo.TestChaining
AS
EXECUTE ('SELECT PersonId, FullName
          FROM   Application.People');
GO
GRANT EXECUTE ON SecurityDemo.TestChaining TO Fred;
GO


EXECUTE AS USER = 'Fred';
EXECUTE SecurityDemo.TestChaining;
REVERT;
GO

ALTER PROCEDURE SecurityDemo.testChaining
WITH EXECUTE AS SELF
AS
EXECUTE ('SELECT PersonId, FullName
          FROM   Application.People');
GO

EXECUTE AS USER = 'Fred';
EXECUTE SecurityDemo.TestChaining;
REVERT;
GO

CREATE PROCEDURE SecurityDemo.YouCanDoAnythingWithDynamicSQL_ButDontDoThis
(
    @query nvarchar(4000)
)
WITH EXECUTE AS SELF
AS
EXECUTE (@query);
GO

--
--Ability to Use the Memory Optimized Engine to Its Fullest
--


USE WideWorldImporters;
GO
CREATE PROCEDURE Warehouse.VehicleTemperatures$Select  
(
        @TemperatureLowRange decimal(10,2) = -99999999.99,
        @TemperatureHighRange decimal(10,2) = 99999999.99
)
WITH SCHEMABINDING, NATIVE_COMPILATION  AS  
  BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
                     LANGUAGE = N'us_english')  
        SELECT VehicleTemperatureID, VehicleRegistration,
               RecordedWhen, Temperature
        FROM   Warehouse.VehicleTemperatures
        WHERE  Temperature BETWEEN @TemperatureLowRange 
                               AND @TemperatureHighRange
        ORDER BY RecordedWhen DESC; --Most Recent First
  END; 
GO

EXECUTE Warehouse.VehicleTemperatures$Select ;
EXECUTE Warehouse.VehicleTemperatures$Select @TemperatureLowRange = 4;
EXECUTE Warehouse.VehicleTemperatures$Select @TemperatureLowRange = 4.1,
                                             @TemperatureHighRange = 4.1;
GO


CREATE PROCEDURE Warehouse.VehicleTemperatures$FixTemperature  
(
        @VehicleTemperatureID int,
        @Temperature decimal(10,2),
		@ThrowErrorFlag bit = 1
)
WITH SCHEMABINDING, NATIVE_COMPILATION AS  
--Simulating a procedure you might write to fix a temperature that was 
--found to be outside of reasonability
  BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
                     LANGUAGE = N'us_english')  
    BEGIN TRY
         --Update the temperature
         UPDATE Warehouse.VehicleTemperatures
         SET       Temperature = @Temperature
         WHERE  VehicleTemperatureID = @VehicleTemperatureID;

         --give the ability to crash the procedure for demo
         --Note, actually doing 1/0 is stopped by the compiler
         DECLARE @CauseFailure int
         SET @CauseFailure =  1/@Temperature;

         --return data if not a fail
         SELECT 'Success' AS Status, VehicleTemperatureID, 
                Temperature
            FROM   Warehouse.VehicleTemperatures
            WHERE  VehicleTemperatureID = @VehicleTemperatureID;
        END TRY
        BEGIN CATCH
            --return data for the fail
            SELECT 'Failure' AS Status, VehicleTemperatureID, 
                   Temperature
            FROM   Warehouse.VehicleTemperatures
            WHERE  VehicleTemperatureID = @VehicleTemperatureID;

			IF @ThrowErrorFlag = 1
              THROW; --This will cause the batch to stop, and will cause this
                     --transaction to not be committed. Cannot use ROLLBACK
                     --does not necessarily end the transaction, even if it 
                     --ends the batch.
        END CATCH;
  END;
GO

--Show original value of temperature for a given row
SELECT Temperature
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 65994;
GO

EXECUTE Warehouse.VehicleTemperatures$FixTemperature
                                    @VehicleTemperatureId = 65994,
                                    @Temperature = 4.2;
GO

EXECUTE Warehouse.VehicleTemperatures$FixTemperature                                                                    
                               @VehicleTemperatureId = 65994,                                                 
                               @Temperature = 0;

SELECT Temperature
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 65994;
GO

EXECUTE Warehouse.VehicleTemperatures$FixTemperature                                                                    
                               @VehicleTemperatureId = 65994,                                                 
                               @Temperature = 0,
                               @ThrowErrorFlag = 0;

SELECT Temperature
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 65994;
GO


UPDATE VehicleTemperatures --Reset the value to the original value
SET    Temperature = 4.18
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 65994;
GO
SELECT @@TRANCOUNT AS TranStart;
BEGIN TRANSACTION
EXECUTE Warehouse.VehicleTemperatures$FixTemperature                                                                 
                             @VehicleTemperatureId = 65994,                                     
                             @Temperature = 0,
                             @ThrowErrorFlag = 1;
GO
SELECT @@TRANCOUNT AS TranEnd;
GO

SELECT Temperature
FROM   Warehouse.VehicleTemperatures
WHERE  VehicleTemperatureID = 65994;
GO

ROLLBACK;
GO


----------------------------------------------------------------------------------------------------------
--*****
--Disadvantages of T-SQL Object Layers
--*****
----------------------------------------------------------------------------------------------------------

--
--Difficulty Affecting Only Certain Columns in an Operation
--

USE Chapter13;
GO

--Missing details like a natural key. Design is only to be 
--used for illustration of coding issue
CREATE TABLE Sales.Contact
(
    ContactId   int CONSTRAINT PKContact PRIMARY KEY,
    FirstName   varchar(30) NOT NULL,
    LastName    varchar(30) NOT NULL,
    CompanyName varchar(100) NOT NULL,
    SalesLevelId  int NOT NULL, --Would be FK in real build
    ContactNotes  varchar(max) NULL
)
GO


CREATE PROCEDURE Sales.Contact$Update
(
    @ContactId   int,
    @FirstName   varchar(30),
    @LastName    varchar(30),
    @CompanyName varchar(100),
    @SalesLevelId  int,
    @ContactNotes  varchar(max)
)
AS
 BEGIN
    BEGIN TRY
          UPDATE Sales.Contact
          SET    FirstName = @FirstName,
                 LastName = @LastName,
                 CompanyName = @CompanyName,
                 SalesLevelId = @SalesLevelId,
                 ContactNotes = @ContactNotes
          WHERE  ContactId = @ContactId;
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
           ROLLBACK TRANSACTION;

      DECLARE @ERRORmessage nvarchar(4000)
      SET @ERRORmessage = 'Error occurred in procedure ''' + 
                  OBJECT_NAME(@@procid) + ''', Original Message: ''' 
                 + ERROR_MESSAGE() + '''';
      THROW 50000,@ERRORmessage,1;
   END CATCH;
 END;
GO

ALTER PROCEDURE Sales.Contact$Update
(
    @ContactId   int,
    @FirstName   varchar(30),
    @LastName    varchar(30),
    @CompanyName varchar(100),
    @SalesLevelId  int,
    @ContactNotes  varchar(max)
)
WITH EXECUTE AS SELF
AS
  BEGIN
    DECLARE @EntryTrancount int = @@TRANCOUNT;

    BEGIN TRY
       --declare variable to use to tell whether to include the sales level
       DECLARE @SalesOrderIdChangedFlag bit = 
                 CASE WHEN (SELECT SalesLevelId 
                            FROM   Sales.Contact
                            WHERE  ContactId = @ContactId) =  @SalesLevelId
                      THEN 0 ELSE 1 END;
  
     DECLARE @query nvarchar(max);
        SET @query = '
        UPDATE Sales.Contact
        SET    FirstName = ' +     
                 --Function created earlier in chapter  
                 Tools.String$EscapeString(@FirstName,DEFAULT,DEFAULT) + ',
               LastName = ' +  
                 Tools.String$EscapeString(@LastName,DEFAULT,DEFAULT) + ',
               CompanyName = ' + 
               Tools.String$EscapeString(@CompanyName,DEFAULT,DEFAULT) + ',
                '+ CASE WHEN @salesOrderIdChangedFlag = 1 THEN 
                'SalesLevelId = ' + CAST(@SalesLevelId AS varchar(10)) + ',
               ' else '' END + ',
               ContactNotes = ' + 
               Tools.String$EscapeString(@ContactNotes,DEFAULT,DEFAULT) + '
         WHERE  ContactId = ' + CAST(@ContactId AS varchar(10)) ;
         EXECUTE (@query);
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
           ROLLBACK TRANSACTION;

      DECLARE @ERRORmessage nvarchar(4000)
      SET @ERRORmessage = 'Error occurred in procedure ''' + 
                  OBJECT_NAME(@@procid) + ''', Original Message: ''' 
                 + ERROR_MESSAGE() + '''';
      THROW 50000,@ERRORmessage,1;
   END CATCH;
 END;
GO

CREATE TRIGGER Sales.Contact$InsteadOfUpdate
ON Sales.Contact
INSTEAD OF UPDATE
AS
BEGIN
   SET NOCOUNT ON;
   SET ROWCOUNT 0; --in case the client has modified the rowcount
   --use inserted for insert or update trigger, deleted for update or  
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @RowsAffected int = (SELECT COUNT(*) FROM inserted);

   --no need to continue on if no rows affected
   IF @RowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation blocks]
          --[modification blocks]
          --<perform action>

          UPDATE Contact
          SET    FirstName = inserted.FirstName,
                 LastName = inserted.LastName,
                 CompanyName = inserted.CompanyName,
                 ContactNotes = inserted.ContactNotes
          FROM   Sales.Contact AS Contact
                    JOIN inserted
                        ON inserted.ContactId = Contact.ContactId

          IF UPDATE(SalesLevelId) --this column requires heavy validation
                                  --only want to update if necessary
               UPDATE Contact
               SET    SalesLevelId = inserted.SalesLevelId
               FROM   Sales.Contact 
                         JOIN inserted
                              ON inserted.ContactId = Contact.ContactId

              --this correlated subquery checks for values that 
              --have changed
              WHERE  EXISTS (SELECT *
                             FROM   deleted
                             WHERE  deleted.ContactId = 
                                             inserted.ContactId
                               AND  deleted.SalesLevelId <> 
                                             inserted.SalesLevelId)
   END TRY
   BEGIN CATCH
               IF @@TRANCOUNT > 0
                     ROLLBACK TRANSACTION;

              THROW;

     END CATCH
END;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Building Reusable Components
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Numbers Table
--*****
----------------------------------------------------------------------------------------------------------

--since CREATE SCHEMA must be in it's own batch, this is how to create it if it doesn't already exist
IF SCHEMA_ID('Tools') IS NULL
	EXEC ('CREATE SCHEMA Tools;')
GO
CREATE TABLE Tools.Number
(
    I   int CONSTRAINT PKNumber PRIMARY KEY
);
--Load it with integers from 0 to 999999:
;WITH digits (I) AS (--set up a set of numbers from 0-9
        SELECT I
        FROM   (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS digits (I))
--builds a table from 0 to 999999
,Integers (I) AS (
       --since you have every combinations of digits, This math turns it 
       --into numbers since every combination of digits is present
        SELECT D1.I + (10*D2.I) + (100*D3.I) + (1000*D4.I) + (10000*D5.I)
               + (100000*D6.I)
        --gives us combinations of every digit
        FROM digits AS D1 CROSS JOIN digits AS D2 CROSS JOIN digits AS D3
                CROSS JOIN digits AS D4 CROSS JOIN digits AS D5
                CROSS JOIN digits AS D6 )
INSERT INTO Tools.Number(I)
SELECT I
FROM   Integers;
GO

SELECT *
FROM  Tools.Number
ORDER BY I;
GO

SELECT People.FullName, Number.I AS Position,
              SUBSTRING(People.FullName,Number.I,1) AS [Char],
              UNICODE(SUBSTRING(People.FullName, Number.I,1)) AS [Unicode]
FROM   Application.People 
         JOIN Tools.Number
               ON Number.I <= LEN(People.FullName )
                   AND  UNICODE(SUBSTRING(People.FullName, Number.I,1)) 
                                                               IS NOT NULL
ORDER  BY FullName;
GO

SELECT People.FullName, Number.I AS Position,
              SUBSTRING(People.FullName,Number.I,1) AS [Char],
              UNICODE(SUBSTRING(People.FullName, Number.I,1)) AS [Unicode]
FROM   Application.People 
         JOIN Tools.Number
               ON Number.I <= LEN(People.FullName )
                   AND  UNICODE(SUBSTRING(People.FullName, Number.I,1)) 
                                                               IS NOT NULL
ORDER  BY FullName;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Calendar Table
--*****
----------------------------------------------------------------------------------------------------------
CREATE TABLE Tools.Calendar
(
        DateValue date NOT NULL CONSTRAINT PKTools_Calendar PRIMARY KEY,
        DayName varchar(10) NOT NULL,
        MonthName varchar(10) NOT NULL,
        Year varchar(60) NOT NULL,
        Day tinyint NOT NULL,
        DayOfTheYear smallint NOT NULL,
        Month smallint NOT NULL,
        Quarter tinyint NOT NULL
);
GO


--load up to the next 2 years
DECLARE @enddate date = CAST(YEAR(GETDATE() + 2) as char(4)) + '0101';
WITH Dates (NewDateValue) AS (
        --pick some base date for your calendar, it doesn’t really matter
        SELECT DATEADD(day,I,'19000101') AS NewDateValue
        FROM Tools.Number
)
INSERT Tools.Calendar
        (DateValue,DayName
        ,MonthName,Year,Day
        ,DayOfTheYear,Month,Quarter
)
SELECT
        Dates.NewDateValue as DateValue,
        DATENAME(dw,Dates.NewDateValue) As DayName,
        DATENAME(mm,Dates.NewDateValue) AS MonthName,
        DATENAME(yy,Dates.NewDateValue) AS Year,
        DATEPART(day,Dates.NewDateValue) AS Day,
        DATEPART(dy,Dates.NewDateValue) AS DayOfTheYear,
        DATEPART(m,Dates.NewDateValue) AS Month,
        DATEPART(qq,Dates.NewDateValue) AS Quarter

FROM    Dates
WHERE   Dates.NewDateValue BETWEEN '20000101' AND @enddate
ORDER   BY DateValue;
GO

SELECT Calendar.Year, COUNT(*) AS OrderCount
FROM   /*WideWorldImporters.*/ Sales.Orders
         JOIN Tools.Calendar
            ON Orders.OrderDate = Calendar.DateValue 
               --OrderDate is a date type column
GROUP BY Calendar.Year
ORDER BY Calendar.Year;
GO

SELECT Calendar.DayName, COUNT(*) as OrderCount
FROM   /*WideWorldImporters.*/ Sales.Orders
         JOIN Tools.Calendar
               --note, the cast here could be a real performance killer
               --consider using date columns where possible
            ON CAST(Orders.OrderDate as date) = Calendar.DateValue
WHERE DayName IN ('Tuesday','Thursday')
GROUP BY Calendar.DayName
ORDER BY Calendar.DayName;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Utility Objects
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Monitoring Objects
----------------------------------------------------------------------------------------------------------

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
CREATE SCHEMA Monitor;
GO

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
	@RecaptureTodaysValuesFlag bit = 0
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

IF @RecaptureTodaysValuesFlag = 1
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


EXEC Monitor.TableRowCount$CaptureRowcounts;
GO

SELECT *
FROM   Monitor.TableRowCount
WHERE  SchemaName = 'Purchasing'
ORDER BY SchemaName, TableName;
GO

SELECT *
FROM   Monitor.TableRowCount
WHERE  SchemaName = 'Monitor'
ORDER BY SchemaName, TableName;
GO
EXEC Monitor.TableRowCount$CaptureRowcounts @RecaptureTodaysValuesFlag = 1
GO
SELECT *
FROM   Monitor.TableRowCount
WHERE  SchemaName = 'Monitor'
ORDER BY SchemaName, TableName;
GO

----------------------------------------------------------------------------------------------------------
--Extended DDL Utilities
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Utility;
GO
CREATE PROCEDURE Utility.Constraints$ResetEnableAndTrustedStatus
(
    @table_name sysname = '%', 
    @table_schema sysname = '%',
    @doFkFlag bit = 1,
    @doCkFlag bit = 1
) as
-- ----------------------------------------------------------------
-- Enables disabled foreign key and check constraints, and sets
-- trusted status so optimizer can use them
--
-- NOTE: This code expects the Monitor.TableRowCount to be in the 
--same db as the tables being monitored. Rework would be needed 
--if this is not a possibility
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org 
-- ----------------------------------------------------------------

 BEGIN

      SET NOCOUNT ON;
      DECLARE @statements cursor; --use to loop through constraints to 
                        -- execute one constraint for individual DDL calls
      SET @statements = CURSOR FOR 
          WITH FKandCHK AS 
               (SELECT OBJECT_SCHEMA_NAME(parent_object_id) AS  schemaName,                                       
                       OBJECT_NAME(parent_object_id) AS tableName,
                       NAME AS constraintName, Type_desc AS constraintType, 
                       is_disabled AS DisabledFlag, 
                       (is_not_trusted + 1) % 2 AS TrustedFlag
                FROM   sys.foreign_keys
                UNION ALL 
                SELECT OBJECT_SCHEMA_NAME(parent_object_id) AS schemaName, 
                       OBJECT_NAME(parent_object_id) AS tableName,
                       NAME AS constraintName, Type_desc AS constraintType, 
                       is_disabled AS DisabledFlag, 
                       (is_not_trusted + 1) % 2 AS TrustedFlag
                FROM   sys.check_constraints )
           SELECT schemaName, tableName, constraintName, constraintType, 
                  DisabledFlag, TrustedFlag 
           FROM   FKandCHK
           WHERE  (TrustedFlag = 0 OR DisabledFlag = 1)
             AND  ((constraintType = 'FOREIGN_KEY_CONSTRAINT' 
                                                AND @doFkFlag = 1)
                    OR (constraintType = 'CHECK_CONSTRAINT' 
                                                AND @doCkFlag = 1))
             AND  schemaName LIKE @table_Schema
             AND  tableName LIKE @table_Name;

      OPEN @statements;

      DECLARE @statement varchar(1000), @schemaName sysname, 
              @tableName sysname, @constraintName sysname, 
              @constraintType sysname,@disabledFlag bit, @trustedFlag bit;

      WHILE 1=1
         BEGIN
              FETCH FROM @statements INTO @schemaName, @tableName, 
                              @constraintName, @constraintType, 
                              @disabledFlag, @trustedFlag;
               IF @@FETCH_STATUS <> 0
                    BREAK;

               BEGIN TRY -- will output an error if it occurs but will keep 
                         -- on going so other constraints will be adjusted

                 IF @constraintType = 'CHECK_CONSTRAINT'
                            SELECT @statement = 'ALTER TABLE ' + 
                                      @schemaName + '.' + @tableName + 
                                      ' WITH CHECK CHECK CONSTRAINT ' 
                                      + @constraintName;
                  ELSE IF @constraintType = 'FOREIGN_KEY_CONSTRAINT'
                            SELECT @statement = 'ALTER TABLE ' +                   
                                     @schemaName + '.' + @tableName + 
                                     ' WITH CHECK CHECK CONSTRAINT ' 
                                     + @constraintName;
                  EXEC (@statement);                                 
              END TRY
              BEGIN CATCH --output statement that was executed along with 
                          --the error number
                  SELECT 'Error occurred: ' + 
                          CAST(ERROR_NUMBER() AS varchar(10))+ ':' +  
                          error_message() + CHAR(13) + CHAR(10) + 
                          'Statement executed: ' +  @statement;
              END CATCH
        END;

   END;
GO


CREATE PROCEDURE Utility.Table$AddExtendedProperty
	@schema_name sysname,
	@table_name sysname,
	@property_name sysname,
	@property_value   sql_variant
AS
 BEGIN
	EXEC sys.sp_addextendedproperty @name = @property_name,
                                         @value = @property_value,
                                         @level0Type = 'Schema',
                                         @level0Name = @schema_name,
                                         @level1Type = 'Table',
                                         @level1Name = @table_name;
  END;
 GO

 CREATE OR ALTER PROCEDURE Utility.Table$DropExtendedProperty
	@schema_name sysname,
	@table_name sysname,
	@property_name sysname
AS
 BEGIN
	EXEC sys.sp_dropextendedproperty @name = @property_name,
                                         @level0Type = 'Schema',
                                         @level0Name = @schema_name,
                                         @level1Type = 'Table',
                                         @level1Name = @table_name;
  END;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Tools Library
--*****
----------------------------------------------------------------------------------------------------------

CREATE OR ALTER FUNCTION Tools.String$SplitPart
(
    @inputValue nvarchar(4000),
    @delimiter  nchar(1) = ',',  
    @position   int = 1
)
------------------------------------------------------------------------
-- Helps to normalize a delimited string by fetching one value from the
-- list. (note, can’t use STRING_SPLIT because return order not guaranteed)
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org 
------------------------------------------------------------------------
RETURNS nvarchar(4000)
WITH SCHEMABINDING, EXECUTE AS CALLER AS
BEGIN
       DECLARE @start int, @end int
       --add commas to end and start
       SET @inputValue = N',' + @inputValue + N',';

       WITH BaseRows AS (
            SELECT Number.I, 
                   ROW_NUMBER() OVER (ORDER BY Number.I) AS StartPosition, 
                   ROW_NUMBER() OVER (ORDER BY Number.I) - 1 AS EndPosition
            FROM   Tools.Number
            WHERE  Number.I <= LEN(@inputValue)
             AND  SUBSTRING(@inputValue,Number.I,1) = @delimiter
       )                   --+1 to deal with commas
       SELECT @start = (SELECT BaseRows.I + 1 FROM BaseRows 
                        WHERE BaseRows.StartPosition = @Position),
              @end = (  SELECT BaseRows.I FROM BaseRows 
                        WHERE BaseRows.EndPosition = @Position)

       RETURN SUBSTRING(@inputValue,@start,@end - @start)
 END;
GO

DECLARE @Value nvarchar(10) = 'a,b,c,d';
SELECT Tools.String$SplitPart(@Value,',',1) AS pt1,
       Tools.String$SplitPart(@Value,',',2) AS pt2,
       Tools.String$SplitPart(@Value,',',3) AS pt3,
       Tools.String$SplitPart(@Value,',',4) AS pt4,
       Tools.String$SplitPart(@Value,',',5) AS pt5;
GO



CREATE OR ALTER PROCEDURE Tools.Table$ListExtendedProperties
	@schema_name_like sysname = '%',
	@table_name_like sysname = '%',
	@property_name_like sysname = '%'
------------------------------------------------------------------------
-- List the extended property on tables, based on a set of like expressions
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org 
------------------------------------------------------------------------

WITH EXECUTE AS OWNER --need extra rights to view extended properties
AS
 BEGIN
	SELECT schemas.name AS schema_name,  tables.name AS table_name, 
	       extended_properties.name AS property_name, 
		   extended_properties.value AS property_value
	FROM   sys.extended_properties 
	           JOIN sys.tables
				JOIN sys.schemas	
					ON tables.schema_id = schemas.schema_id
			ON tables.object_id = extended_properties.major_id
	WHERE  extended_properties.class_desc = 'OBJECT_OR_COLUMN'
	  AND  extended_properties.minor_id = 0
	  AND  schemas.name LIKE @schema_name_like
	  AND  tables.name LIKE @table_name_like
	  AND  extended_properties.name LIKE @property_name_like
	ORDER BY schema_name, table_name, property_name;
  END
GO

EXECUTE Utility.Table$AddExtendedProperty @schema_name = 'Sales',
	@table_name = 'Invoices', 	@property_name = 'DBDesignBook',
	@property_value = 'Tested';
GO

EXEC Tools.Table$ListExtendedProperties @schema_name_like = 'Sales', 
	@table_name_like = 'Invoices';
GO

EXECUTE Utility.Table$DropExtendedProperty @schema_name = 'Sales',
	@table_name = 'Invoices', 	@property_name = 'DBDesignBook';
GO

EXEC Tools.Table$ListExtendedProperties @schema_name_like = 'Sales', 
	@table_name_like = 'Invoices';
GO

CREATE OR ALTER FUNCTION Tools.SystemSecurityName$Get
(
     @AllowSessionContext bit = 1,
     @IgnoreImpersonation bit = 0
)
------------------------------------------------------------------------
-- Get the user’s security context, using SESSION_CONTEXT, SUSER_SNAME,
-- or ORIGINAL_LOGIN
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org 
------------------------------------------------------------------------
RETURNS sysname
AS
 BEGIN
    RETURN (
     CASE WHEN @AllowSessionContext = 1 
                 AND SESSION_CONTEXT(N'ApplicationUserName') IS NOT NULL
              THEN CAST(SESSION_CONTEXT(N'ApplicationUserName') AS sysname)
          WHEN @IgnoreImpersonation = 1
              THEN SUSER_SNAME()
          ELSE ORIGINAL_LOGIN() END)
 END;
GO

GRANT EXECUTE ON Tools.SystemSecurityName$Get to Public;
GO

CREATE LOGIN Tester WITH PASSWORD = '820q0qjc,nm98ur';
CREATE USER Tester FOR LOGIN Tester;
EXECUTE AS Login = 'Tester';
GO

--allow session context and ignore impersonation
SELECT Tools.SystemSecurityName$Get(DEFAULT, DEFAULT) AS LoginName;
GO

EXEC sys.sp_set_session_context @key = N'ApplicationUserName', 
            @value = 'Louis';
GO

--Ignore sesson context, allow impersonation
SELECT Tools.SystemSecurityName$Get(0, 1) AS LoginName;
GO


EXEC sys.sp_set_session_context 
          @key = N'ApplicationUserName', @value = NULL;

REVERT;
DROP USER Tester;
DROP LOGIN Tester;
GO



CREATE SCHEMA MemOptTools;
GO
CREATE OR ALTER FUNCTION MemOptTools.String$Replicate
(
    @inputString    nvarchar(1000),
    @replicateCount smallint
)
RETURNS nvarchar(1000)
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH(TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
                  LANGUAGE = N'English')
    DECLARE @i int = 0, @output nvarchar(1000) = '';

    WHILE @i < @replicateCount
    BEGIN
        SET @output = @output + @inputString;
        SET @i = @i + 1;
    END;

    RETURN @output;
END;
GO

SELECT MemOptTools.String$Replicate('Test',20);
GO

----------------------------------------------------------------------------------------------------------
--*****
--Logging Objects
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA ErrorHandling;
GO
CREATE TABLE ErrorHandling.ErrorLog(
        ErrorLogId int NOT NULL IDENTITY CONSTRAINT PKErrorLog PRIMARY KEY,
                Number int NOT NULL,
        Location sysname NOT NULL,
        Message varchar(4000) NOT NULL,
        LogTime datetime2(3) NULL
              CONSTRAINT DFLTErrorLog_LogTime  DEFAULT (SYSDATETIME()),
        ServerPrincipal sysname NOT NULL
        --use original_login to capture the user name of the actual user
        --not a user they have impersonated
        CONSTRAINT DFLTErrorLog_ServerPrincipal DEFAULT (ORIGINAL_LOGIN())
);
GO

CREATE PROCEDURE ErrorHandling.ErrorLog$Insert
(
        @ERROR_NUMBER int,
        @ERROR_LOCATION sysname,
        @ERROR_MESSAGE nvarchar(4000)
) AS
------------------------------------------------------------------------
-- Writes a row to the error log. If an error occurs in the call (such as a 
-- NULL value) It writes a row to the error table. If that call fails an 
-- error will be returned
--
-- 2020 Louis Davidson – drsql@hotmail.com – drsql.org 
------------------------------------------------------------------------

 BEGIN
        SET NOCOUNT ON;
        BEGIN TRY
           INSERT INTO ErrorHandling.ErrorLog(Number, Location,Message)
           SELECT @ERROR_NUMBER,
                  COALESCE(@ERROR_LOCATION, N'No Object'),@ERROR_MESSAGE;
        END TRY
        BEGIN CATCH
           INSERT INTO ErrorHandling.ErrorLog(Number, Location, Message)
           VALUES (-100, 'Utility.ErrorLog$Insert',
                   'An invalid call was made to the error log procedure ' +  
                   ERROR_MESSAGE());
        END CATCH;
END;
GO

--test the error block we will use
BEGIN TRY
    THROW 50000,'Test error',1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    --[Error logging section]
        DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
        EXEC ErrorHandling.ErrorLog$Insert 
                      @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

    THROW; --will halt the batch or be caught by the caller's catch block

END CATCH;
GO

--Left off ServerPrincipal for space
SELECT ErrorLogId, Number, Location, Message, LogTime
FROM  ErrorHandling.ErrorLog;
GO

