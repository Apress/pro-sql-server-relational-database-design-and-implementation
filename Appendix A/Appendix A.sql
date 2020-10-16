EXIT

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Numeric Data
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Integer Values
--*****
----------------------------------------------------------------------------------------------------------

SELECT 1/2;
GO

SELECT 305 / 100, 305 % 100;
GO

SELECT  CAST(305 AS numeric)/ 100, (305 * 1.0) / 100;
GO

SELECT CAST(.99999999 AS integer);
GO


----------------------------------------------------------------------------------------------------------
--*****
--Precise Numeric Values
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--decimal and numeric
----------------------------------------------------------------------------------------------------------

SELECT name, system_type_id
FROM   sys.types
WHERE  name IN ('decimal','numeric');
GO

DECLARE @testvar decimal(3,1);
SELECT @testvar = -10.155555555;
SELECT @testvar;
GO

SET NUMERIC_ROUNDABORT ON;

DECLARE @testvar decimal(3,1);
SELECT @testvar = -10.155555555;

SET NUMERIC_ROUNDABORT OFF ;--this setting persists for a connection
GO

----------------------------------------------------------------------------------------------------------
--money and smallmoney
----------------------------------------------------------------------------------------------------------
USE tempdb
GO
CREATE TABLE dbo.TestMoney
(
    MoneyValue money
);
go

INSERT INTO dbo.TestMoney
VALUES ($100);
INSERT INTO dbo.TestMoney
VALUES (100);
INSERT INTO dbo.TestMoney
VALUES (£100);
GO
SELECT * FROM dbo.TestMoney WHERE MoneyValue = $100;
GO

DECLARE @money1 money  = 1.00,
        @money2 money  = 800.00; --same result with one of these integer

SELECT CAST(@money1/@money2 AS money);


DECLARE @decimal1 decimal(19,4) = 1.00,
        @decimal2 decimal(19,4) = 800.00;

SELECT  CAST(@decimal1/@decimal2 AS decimal(19,4));

SELECT  @money1/@money2;
SELECT  @decimal1/@decimal2;

GO

----------------------------------------------------------------------------------------------------------
--*****
--Approximate Numeric Data
--*****
----------------------------------------------------------------------------------------------------------

DECLARE @FirstApproximate REAL = 22.33
SELECT @FirstApproximate --sql server renders the view of output correctly
SELECT STR(@FirstApproximate,20,16) --but the whole value gets messy
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Date and Time Data
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--datetimeoffset [(precision)]
--*****
----------------------------------------------------------------------------------------------------------

DECLARE @LocalTime datetimeoffset;
SET @LocalTime = SYSDATETIMEOFFSET();
SELECT @LocalTime;
SELECT SWITCHOFFSET(@LocalTime, '+00:00') AS UTCTime;

----------------------------------------------------------------------------------------------------------
--*****
--datetime
--*****
----------------------------------------------------------------------------------------------------------

SELECT CAST('20110919 23:59:59.999' AS datetime);
GO

SELECT CAST('20110919 23:59:59.997' AS datetime);
GO

----------------------------------------------------------------------------------------------------------
--*****
--Discussion on All Date Types
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Representing Dates in Text Formats
----------------------------------------------------------------------------------------------------------

SELECT CAST('2013-01-01' AS date) AS DateOnly;
SELECT CAST('2013-01-01 14:23:00.003' AS datetime) AS WithTime;
GO

SELECT CAST ('20130101' AS date) AS DateOnly;
SELECT CAST('2013-01-01T14:23:00.120' AS datetime) AS WithTime;
GO

DECLARE @DateValue datetime2(3) = '2012-05-21 15:45:01.456'
SELECT @DateValue AS Unformatted,
       FORMAT(@DateValue,'yyyyMMdd') AS IsoUnseparated, 
       FORMAT(@DateValue,'yyyy-MM-ddThh:mm:ss') AS IsoDateTime, 
       FORMAT(@DateValue,'D','en-US') AS USRegional,
       FORMAT(@DateValue,'D','en-GB') AS GBRegional,
       FORMAT(@DateValue,'D','fr-fr') AS FRRegional;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Character Strings
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------


----------------------------------------------------------------------------------------------------------
--*****
--char[(number of bytes)]
--*****
----------------------------------------------------------------------------------------------------------

--Create tables with the same datatype of char
--one with DATA_COMPRESSION

CREATE TABLE dbo.TestChar
(
	value char(100)
);

CREATE TABLE dbo.TestChar2
(
	value char(100)
)
WITH (DATA_COMPRESSION = PAGE);
GO
--insert the exact same data
INSERT INTO dbo.TestChar(value)
VALUES('1234567890');
INSERT INTO dbo.TestChar2(value)
VALUES('1234567890');
GO
--output the length of the text, and the amount of memory used
SELECT LEN(value), DATALENGTH(value)
FROM   dbo.TestChar;
SELECT LEN(value), DATALENGTH(value)
FROM   dbo.TestChar2;
GO

----------------------------------------------------------------------------------------------------------
--*****
--varchar(max)
--*****
----------------------------------------------------------------------------------------------------------

DECLARE @value varchar(max) = REPLICATE('X',8000) + REPLICATE('X',8000);
SELECT LEN(@value);
GO

DECLARE @value varchar(max) = REPLICATE(CAST('X' AS varchar(max)),8000) 
                              + REPLICATE(CAST('X' AS varchar(max)),8000);
SELECT LEN(@value);
GO

----------------------------------------------------------------------------------------------------------
--*****
--Unicode Character Strings: nchar(double byte length), nvarchar(double byte length), nvarchar(max), ntext
--*****
----------------------------------------------------------------------------------------------------------

 SELECT N'Unicode Value';
 GO

 ----------------------------------------------------------------------------------------------------------
 --********************************************************************************************************
 --Binary Data
 --********************************************************************************************************
 ----------------------------------------------------------------------------------------------------------
 
 ----------------------------------------------------------------------------------------------------------
 --*****
 --binary[(number of bytes)]
 --*****
 ----------------------------------------------------------------------------------------------------------
 
DECLARE @value binary(10)  = CAST('helloworld' AS binary(10));
SELECT @value;
GO

SELECT CAST(0x68656C6C6F776F726C64 AS varchar(10));
GO

DECLARE @value binary(10)  = CAST('HELLOWORLD' AS binary(10));
SELECT @value;

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Other Datatypes
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Bit
--*****
----------------------------------------------------------------------------------------------------------
SELECT CAST ('True' AS bit) AS True, CAST('False' AS bit) AS False
GO

----------------------------------------------------------------------------------------------------------
--*****
--rowversion (aka timestamp)
--*****
----------------------------------------------------------------------------------------------------------

SET NOCOUNT ON;
CREATE TABLE dbo.TestRowversion
(
   Value   varchar(20) NOT NULL,
   Auto_rv   rowversion NOT NULL
);

INSERT INTO dbo.TestRowversion (Value) 
VALUES('Insert');

SELECT Value, Auto_rv 
FROM dbo.testRowversion;

UPDATE dbo.TestRowversion
SET Value = 'First Update';

SELECT Value, Auto_rv 
FROM dbo.TestRowversion;

UPDATE dbo.TestRowversion
SET Value = 'Last Update'; 

SELECT Value, auto_rv
FROM dbo.TestRowversion;
GO

----------------------------------------------------------------------------------------------------------
--*****
--uniqueidentifier
--*****
----------------------------------------------------------------------------------------------------------

DECLARE @guidVar uniqueidentifier = NEWID();

SELECT @guidVar AS GuidVar;
GO

CREATE TABLE dbo.GuidPrimaryKey
(
   GuidPrimaryKeyId uniqueidentifier NOT NULL ROWGUIDCOL 
   CONSTRAINT PKGuidPrimaryKey PRIMARY KEY 
   CONSTRAINT DFLTGuidPrimaryKey_GuidPrimaryKeyId DEFAULT NEWID(),
   Value varchar(10)
);
GO
INSERT INTO dbo.GuidPrimaryKey(Value)
VALUES ('Test');
GO
SELECT *
FROM   dbo.GuidPrimaryKey;
GO

DROP TABLE dbo.GuidPrimaryKey;
GO
CREATE TABLE dbo.GuidPrimaryKey
(
   GuidPrimaryKeyId uniqueidentifier NOT NULL
          ROWGUIDCOL CONSTRAINT DFLTGuidPrimaryKey_GuidPrimaryKeyId
                             DEFAULT NEWSEQUENTIALID()
          CONSTRAINT PKGuidPrimaryKey PRIMARY KEY,
   Value varchar(10) NOT NULL
);
GO
INSERT INTO dbo.GuidPrimaryKey(value)
VALUES('Test'),  
      ('Test1'),
      ('Test2');
GO

SELECT *
FROM   GuidPrimaryKey;

GO

----------------------------------------------------------------------------------------------------------
--*****
--table
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Table Variables
----------------------------------------------------------------------------------------------------------
DECLARE @tableVar TABLE
(
   Id int IDENTITY PRIMARY KEY,
   Value varchar(100)
);
INSERT INTO @tableVar (Value)
VALUES ('This is a cool test');

SELECT Id, Value
FROM   @tableVar;
GO

CREATE FUNCTION dbo.Table$TestFunction
(
   @returnValue varchar(100)

)
RETURNS @tableVar table
(
     Value varchar(100)
)
AS
BEGIN
   INSERT INTO @tableVar (Value)
   VALUES (@returnValue);

   RETURN;
END;
GO

SELECT *
FROM dbo.Table$testFunction('testValue');
GO

DECLARE @tableVar TABLE
(
   Id int IDENTITY,
   Value varchar(100)
);
BEGIN TRANSACTION;

INSERT INTO @tableVar (Value)
VALUES ('This will still be there');

ROLLBACK TRANSACTION;

SELECT Id, Value
FROM @tableVar;
GO


----------------------------------------------------------------------------------------------------------
--Table-Values Parameters
----------------------------------------------------------------------------------------------------------
USE WideWorldImporters;
GO
CREATE TYPE GenericIdList AS TABLE
(
    Id Int PRIMARY KEY
);
GO

DECLARE @PeopleIdList GenericIdList;
INSERT INTO @PeopleIdList
VALUES (1),(2),(3),(4);

SELECT PersonId, FullName
FROM   Application.People
         JOIN @PeopleIdList AS list
            on People.PersonId = List.Id;
GO

--database must support in-memory with in-mem filegroup
CREATE TYPE GenericIdList_InMem AS TABLE
(
    Id Int PRIMARY KEY NONCLUSTERED 
    --Use nonclustered here,  as it should be fine for typical uses
) WITH (MEMORY_OPTIMIZED = ON);
GO

DECLARE @PeopleIdList GenericIdList_InMem;
INSERT INTO @PeopleIdList
VALUES (2),(3),(4);

SELECT PersonId, FullName
FROM   Application.People
         JOIN @PeopleIdList AS list
            ON People.PersonId = List.Id;
GO


CREATE PROCEDURE Application.People$List
(
    @PeopleIdList GenericIdList READONLY
)
AS
SELECT PersonId, FullName
FROM   Application.People
         JOIN @PeopleIdList AS List
            ON People.PersonId = List.Id;
GO

DECLARE @PeopleIdList GenericIdList;

INSERT INTO @PeopleIdList
VALUES (2),(3),(4);

EXEC Application.People$List @PeopleIdList;
GO

----------------------------------------------------------------------------------------------------------
--*****
--sql_variant
--*****
----------------------------------------------------------------------------------------------------------

DECLARE @varcharVariant sql_variant = '1234567890';

SELECT @varcharVariant AS VarcharVariant,
   SQL_VARIANT_PROPERTY(@varcharVariant,'BaseType') AS BaseType,
   SQL_VARIANT_PROPERTY(@varcharVariant,'MaxLength') AS MaxLength,
   SQL_VARIANT_PROPERTY(@varcharVariant,'Collation') AS Collation;
GO

DECLARE @numericVariant sql_variant = 123456.789;

SELECT @numericVariant AS NumericVariant,
   SQL_VARIANT_PROPERTY(@numericVariant,'BaseType') AS BaseType,
   SQL_VARIANT_PROPERTY(@numericVariant,'MaxLength') AS MaxLength,
   SQL_VARIANT_PROPERTY(@numericVariant,'Collation') AS Collation;
GO

DECLARE @varcharVariant int = 1234567890;
DECLARE @varcharVariant2 varchar(10) = '1234567890';

SELECT 'Value Matches'
WHERE  @varcharVariant = @varcharVariant2;
GO

DECLARE @varcharVariant sql_variant = 1234567890;
DECLARE @varcharVariant2 sql_variant = '1234567890';

SELECT 'Value Matches'
WHERE  @varcharVariant = @varcharVariant2;
GO

