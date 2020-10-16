--since CREATE SCHEMA must be in it's own batch, this is how to create it if it doesn't already exist
IF SCHEMA_ID('Tools') IS NULL
	EXEC ('CREATE SCHEMA Tools;')
GO
--TODO: Add security to this schema after you create.

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

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Numbers table
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

IF OBJECT_ID('Tools.Number') IS NULL
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
FROM   Integers
WHERE  I NOT IN (SELECT I FROM TOols.Number);


----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Calendar Table
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

IF OBJECT_ID('Tools.Calendar') IS NULL
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
  AND   Dates.NewDateValue NOT IN (SELECT DateValue FROM Tools.Calendar)
ORDER   BY DateValue;

