EXIT


--Database I will use for examples in this appendix
CREATE DATABASE AppendixB;
GO
USE AppendixB;
GO
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
           VALUES (-100, 'Utility.ErrorLog$insert',
                   'An invalid call was made to the error log procedure ' +  
                   ERROR_MESSAGE());
        END CATCH;
END;

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--AFTER TRIGGERS
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.Test
(
     TestId int
);
GO


CREATE TRIGGER Demo.Test$InsertUpdateDeleteTrigger
ON Demo.Test
AFTER INSERT, UPDATE, DELETE AS
BEGIN
--stores the number of rows affected
       DECLARE @rowcount int = @@ROWCOUNT,    
	         @rowcountInserted int = (SELECT COUNT(*) FROM inserted),
	         @rowcountDeleted int = (SELECT COUNT(*) FROM deleted);
     
	 SELECT @rowcount as [@@ROWCOUNT], 
	        @rowcountInserted as [@rowcountInserted],
	        @rowcountDeleted as [@rowcountDeleted],
			CASE WHEN @rowcountInserted = 0 THEN 'DELETE'
			     WHEN @rowcountDeleted = 0 THEN 'INSERT'
				 ELSE 'UPDATE' END AS Operation;
END;
GO

EXEC sp_configure 'show advanced options',1;
RECONFIGURE;
GO 
EXEC sp_configure 'disallow results from triggers',0;
RECONFIGURE; 
GO

INSERT INTO Demo.test
VALUES (1),
       (2);
GO

WITH   testMerge AS (SELECT *
                     FROM   (VALUES(2),(3)) AS testMerge (TestId))
MERGE  Demo.Test
USING  (SELECT TestId FROM testMerge) AS source (TestId)
        ON (Test.TestId = source.TestId)
WHEN MATCHED THEN  
	UPDATE SET TestId = source.TestId
WHEN NOT MATCHED THEN
	INSERT (TestId) VALUES (Source.TestId)
WHEN NOT MATCHED BY SOURCE THEN 
        DELETE;
GO




CREATE SCHEMA Example;
GO
--this is the “transaction” table 
CREATE TABLE Example.AfterTriggerExample
(
        AfterTriggerExampleId  int  
                 CONSTRAINT PKAfterTriggerExample PRIMARY KEY,
        GroupingValue          varchar(10) NOT NULL,
        Value                  int NOT NULL
);
GO

--this is the table that holds the summary data
CREATE TABLE Example.AfterTriggerExampleGroupBalance
(
        GroupingValue  varchar(10) NOT NULL 
                 CONSTRAINT PKAfterTriggerExampleGroupBalance PRIMARY KEY,
        Balance        int NOT NULL
);
GO



CREATE TRIGGER Example.AfterTriggerExample$InsertTrigger
ON Example.AfterTriggerExample
AFTER INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

      --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);
       
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
      --[validation section] 
      --Use a WHERE EXISTS to inserted to make sure not 
      --to duplicate rows in the set if > 1 row is modified for the 
      --same grouping value
      IF EXISTS (SELECT AfterTriggerExample.GroupingValue
                 FROM   Example.AfterTriggerExample
                 WHERE  EXISTS (SELECT *
                                FROM Inserted 
                                WHERE  AfterTriggerExample.GroupingValue 
                                            = Inserted.Groupingvalue)
                                GROUP  BY AfterTriggerExample.GroupingValue
                                HAVING SUM(Value) < 0)
 

          BEGIN
             IF @rowsAffected = 1
               SELECT @msg = CONCAT('Grouping Value "', GroupingValue, 
                  '" balance value after operation must be greater than 0')
               FROM   inserted;
             ELSE
               SELECT @msg = CONCAT('The total for grouping values ',
                                        ' must be greater than 0');
                   THROW  50000, @msg, 16;
              END;
                         
          --[modification section]
          --get the balance for any Grouping Values used 
          --in the DML statement
          WITH GroupBalance AS
          (SELECT  AfterTriggerExample.GroupingValue, 
                   SUM(Value) AS NewBalance
           FROM   Example.AfterTriggerExample
           WHERE  EXISTS (SELECT *
                          FROM Inserted 
                          WHERE  AfterTriggerExample.GroupingValue = 
                                                    Inserted.Groupingvalue)
           GROUP  BY AfterTriggerExample.GroupingValue )

         --use merge because there may not be an existing balance row for 
         --the grouping value
         MERGE Example.AfterTriggerExampleGroupBalance
         USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                   AS source (GroupingValue, NewBalance)
          ON    (AfterTriggerExampleGroupBalance.GroupingValue = 
                                          source.GroupingValue)
          WHEN MATCHED THEN --a grouping value already existed
                 UPDATE SET Balance = source.NewBalance
          WHEN NOT MATCHED THEN --this is a new grouping value
                 INSERT (GroupingValue, Balance)
                 VALUES (Source.GroupingValue, Source.NewBalance);
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                   @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                   @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
          EXEC ErrorHandling.ErrorLog$Insert 
                          @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END;
GO

INSERT INTO Example.AfterTriggerExample
                              (AfterTriggerExampleId,GroupingValue,Value)
VALUES (1,'Group A',100);
GO
INSERT INTO Example.AfterTriggerExample
                              (AfterTriggerExampleId,GroupingValue,Value)
VALUES (2,'Group A',-50);
GO

--causes error
INSERT INTO Example.AfterTriggerExample
                              (AfterTriggerExampleId,GroupingValue,Value)
VALUES (3,'Group A',-1000);
GO


INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (3,'Group A',10),
       (4,'Group A',-100);
GO

SELECT ErrorLog.Message,Logtime, ErrorLog.ServerPrincipal
FROM   ErrorHandling.ErrorLog
WHERE  ErrorLog.Location = 'AfterTriggerExample$InsertTrigger';
GO

INSERT INTO Example.AfterTriggerExample(AfterTriggerExampleId,GroupingValue,Value)
VALUES (5,'Group A',100), 
       (6,'Group B',200),
       (7,'Group B',150);
GO

SELECT *
FROM   Example.AfterTriggerExample;
SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

SELECT GroupingValue, SUM(Value) AS Balance
FROM   Example.AfterTriggerExample
GROUP  BY GroupingValue;
GO


CREATE TRIGGER Example.AfterTriggerExample$UpdateTrigger
ON Example.AfterTriggerExample
AFTER UPDATE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

      --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
      --[validation section] 
      --Use a WHERE EXISTS to inserted to make sure 
      --not to duplicate rows in the set
      --if > 1 row is modified for the same grouping value
      IF EXISTS (SELECT AfterTriggerExample.GroupingValue
                 FROM   Example.AfterTriggerExample
                 --need to check total on any rows that were 
                 --modified, even if key change
                 WHERE  EXISTS (SELECT *                                                                           
                                FROM   Inserted 
                                WHERE  AfterTriggerExample.GroupingValue = 
                                                     Inserted.Groupingvalue
                                UNION ALL
                                SELECT *
                                FROM   Deleted
                                WHERE  AfterTriggerExample.GroupingValue = 
                                                     Deleted.Groupingvalue)
                                GROUP  BY AfterTriggerExample.GroupingValue
                                HAVING SUM(Value) < 0)
         BEGIN
            IF @rowsAffected = 1
                SELECT @msg = CONCAT('Grouping Value "',     
                                     COALESCE(inserted.GroupingValue,
                                              deleted.GroupingValue),                  
                                    '" balance value after operation must',   
                                    ' be greater than 0')
                                --only one row could be returned...
                                FROM   inserted 
                                          CROSS JOIN deleted;
            ELSE
                SELECT @msg = CONCAT('The total for the grouping value ',             
                                     'must be greater than 0');

                THROW  50000, @msg, 16;
      END

      --[modification section]
      --get the balance for any Grouping Values used in the DML statement
      --we know we will be summing on a NULL, with no better way
      SET ANSI_WARNINGS OFF; 
      WITH GroupBalance AS
      (SELECT ChangedRows.GroupingValue, SUM(Value) as NewBalance
       FROM   Example.AfterTriggerExample
       --the right outer join makes sure that we get all groups, 
       --even if no data remains in the table for a set
                 RIGHT OUTER JOIN
                       (SELECT GroupingValue
                        FROM Inserted 
                        UNION 
                        SELECT GroupingValue
                        FROM Deleted ) as ChangedRows
                 --the join make sure we only get rows for changed 
                 --grouping values
                    ON ChangedRows.GroupingValue = 
                                      AfterTriggerExample.GroupingValue
      GROUP  BY ChangedRows.GroupingValue  )

   --use merge because the user may change the grouping value, and 
   --That could even cause a row in the balance table to need to be deleted
      MERGE Example.AfterTriggerExampleGroupBalance
      USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                     AS source (GroupingValue, NewBalance)
             ON (AfterTriggerExampleGroupBalance.GroupingValue = 
                                                   source.GroupingValue)
      --should only happen with changed key
      WHEN MATCHED and Source.NewBalance IS NULL 
              THEN DELETE
      WHEN MATCHED THEN --normal case, where an amount was updated
              UPDATE SET Balance = source.NewBalance
      WHEN NOT MATCHED THEN --should only happen with changed 
                            --key that didn't previously exist
              INSERT (GroupingValue, Balance)
              VALUES (Source.GroupingValue, Source.NewBalance);
       
          SET ANSI_WARNINGS ON; 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
              @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
              @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
      EXEC ErrorHandling.ErrorLog$Insert 
                     @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH;
END;
GO

UPDATE Example.AfterTriggerExample
SET    Value = 50 --Was 100
WHERE  AfterTriggerExampleId = 5;

GO

SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--Changing the group key
UPDATE Example.AfterTriggerExample
SET    GroupingValue = 'Group C'
WHERE  GroupingValue = 'Group B';
GO


SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--all rows
UPDATE Example.AfterTriggerExample
SET    Value = 10 ;
GO

SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--violate business rules
UPDATE Example.AfterTriggerExample
SET    Value = -10; 
GO

CREATE TRIGGER Example.AfterTriggerExample$DeleteTrigger
ON Example.AfterTriggerExample
AFTER DELETE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   --      @rowsAffected int = (SELECT COUNT(*) FROM inserted);
           @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
     --[validation section] 
     --Use a WHERE EXISTS to inserted to make sure not to 
     --duplicate rows in the set if > 1 row is modified for the same 
     --grouping value
     IF EXISTS (SELECT AfterTriggerExample.GroupingValue
                FROM   Example.AfterTriggerExample
                WHERE  EXISTS (SELECT * --delete trigger needs only check
                               FROM   deleted -- deleted rows
                               WHERE  AfterTriggerExample.GroupingValue = 
                                                     deleted.Groupingvalue)
                GROUP  BY AfterTriggerExample.GroupingValue
               HAVING SUM(Value) < 0)





           BEGIN
              IF @rowsAffected = 1
                  SELECT @msg = CONCAT('Grouping Value "', GroupingValue, 
                                '" balance value after operation must ',
                                'be greater than 0')
                  FROM   deleted; --use deleted for deleted trigger
              ELSE
                  SELECT @msg = CONCAT('The total for the grouping value ',                       
                                       'must be greater than 0');
                  THROW  50000, @msg, 16;
          END

          --[modification section]
          --get the balance for any Grouping Values used in the DML 
          --statement
           SET ANSI_WARNINGS OFF; --we know we will be summing on a NULL 
           WITH GroupBalance AS
              (SELECT ChangedRows.GroupingValue, SUM(Value) as NewBalance
               FROM   Example.AfterTriggerExample
               --the right outer join makes sure that we get all groups,
               --even if no data remains in the table for a set
                       RIGHT OUTER JOIN
                              (SELECT GroupingValue
                               FROM Deleted ) as ChangedRows
                            --the join make sure we only get rows for 
                            --changed grouping values
                            ON ChangedRows.GroupingValue = 
                                        AfterTriggerExample.GroupingValue
               GROUP  BY ChangedRows.GroupingValue)

          --using merge because the delete may or may not remove the last 
         --row for a group which could even cause a row in the balance 
         --table to need to be deleted
         MERGE Example.AfterTriggerExampleGroupBalance
         USING (SELECT GroupingValue, NewBalance FROM GroupBalance) 
                                     AS source (GroupingValue, NewBalance)
         ON (AfterTriggerExampleGroupBalance.GroupingValue = 
                                                    source.GroupingValue)
         WHEN MATCHED and Source.NewBalance IS NULL -- deleted the last key
               THEN DELETE
         WHEN MATCHED THEN --there were still rows left after the delete
               UPDATE SET Balance = source.NewBalance;
                       
          SET ANSI_WARNINGS ON; --restore proper setting
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      --[Error logging section]
      DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
              @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
              @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE()
      EXEC ErrorHandling.ErrorLog$Insert 
                     @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH;
END;
GO

--causes error
UPDATE Example.AfterTriggerExample
SET    Value = -5
WHERE  AfterTriggerExampleId in (2,5); 

UPDATE Example.AfterTriggerExample
SET    Value = -10
WHERE  AfterTriggerExampleId  = 6;
GO

SELECT *
FROM   Example.AfterTriggerExample

SELECT *
FROM   Example.AfterTriggerExampleGroupBalance;
GO

--causes error
DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId = 1;
GO

--causes error
DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId in (1,7);
GO

DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId = 6;
GO

INSERT INTO Example.AfterTriggerExample
VALUES (8, 'Group B',10);
GO

DELETE FROM Example.AfterTriggerExample
WHERE  AfterTriggerExampleId in (1,2,5);
GO

DELETE FROM Example.AfterTriggerExample;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--INSTEAD OF Triggers
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE TABLE Example.InsteadOfTriggerExample
(
        InsteadOfTriggerExampleId  int NOT NULL 
                        CONSTRAINT PKInsteadOfTriggerExample PRIMARY KEY,
        FormatUpper  varchar(30) NOT NULL,
        RowCreatedTime datetime2(3) NOT NULL,
        RowLastModifiedTime datetime2(3) NOT NULL
);
GO

CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfInsertTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
          @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --     @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
      --[validation section]
      --[modification section]
      --<perform action> --this is all I change other than the name and 
                         --table in the trigger declaration/heading
      INSERT INTO Example.InsteadOfTriggerExample                
                 (InsteadOfTriggerExampleId,FormatUpper,
                  RowCreatedTime,RowLastModifiedTime)
      --uppercase the FormatUpper column, set the %time columns to 
      --system time
      SELECT InsteadOfTriggerExampleId, UPPER(FormatUpper),
             SYSDATETIME(),SYSDATETIME()                                                                 
      FROM   inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

          --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                  @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                  @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
          EXEC ErrorHandling.ErrorLog$Insert 
                          @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH;
END;
GO

INSERT INTO Example.InsteadOfTriggerExample 
                                 (InsteadOfTriggerExampleId,FormatUpper)
VALUES (1,'not upper at all');
GO

SELECT FormatUpper, RowCreatedTime, RowLastModifiedTime
FROM   Example.InsteadOfTriggerExample;
GO

INSERT INTO Example.InsteadOfTriggerExample
                                    (InsteadOfTriggerExampleId,FormatUpper)
VALUES (2,'UPPER TO START'),(3,'UpPeRmOsT tOo!');
GO

SELECT FormatUpper, RowCreatedTime, RowLastModifiedTime
FROM   Example.InsteadOfTriggerExample;
GO

--causes an error
INSERT INTO Example.InsteadOfTriggerExample 
                                    (InsteadOfTriggerExampleId,FormatUpper)
VALUES (4,NULL) ;
GO

CREATE TRIGGER Example.InsteadOfTriggerExample$InsteadOfUpdateTrigger
ON Example.InsteadOfTriggerExample
INSTEAD OF UPDATE AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
         @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --    @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action> 
          --note, this trigger assumes non-editable keys. Consider 
          --adding an non-editable surrogate key (even non-pk) 
          --if you need to be able to modify the primary key values
          --as you need something to correlate inserted rows to 
          --existing or deleted rows.
          UPDATE InsteadOfTriggerExample 
          SET    FormatUpper = UPPER(inserted.FormatUpper),
                --RowCreatedTime, Leave this value out 
                 RowLastModifiedTime = SYSDATETIME() --force this value
          FROM   inserted
                   JOIN Example.InsteadOfTriggerExample 
                       ON inserted.InsteadOfTriggerExampleId = 
                         InsteadOfTriggerExample.InsteadOfTriggerExampleId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

          --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                  @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                  @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
          EXEC ErrorHandling.ErrorLog$Insert 
                          @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH;
END;
GO

UPDATE  Example.InsteadOfTriggerExample
SET     RowCreatedTime = '1900-01-01',
        RowLastModifiedTime = '1900-01-01',
        FormatUpper = 'final test'
WHERE   InsteadOfTriggerExampleId in (1,2);
GO


CREATE TABLE Example.TestIdentity
(
	TestIdentityId int IDENTITY CONSTRAINT PKestIdentity PRIMARY KEY,
	Value varchar(30) CONSTRAINT AKtestIdentity UNIQUE,
);
GO

INSERT INTO Example.TestIdentity(Value)
VALUES ('without trigger');

SELECT SCOPE_IDENTITY() AS NewTestIdentityId;
GO


CREATE TRIGGER TestIdentity$InsteadOfInsertTrigger
ON Example.TestIdentity
INSTEAD OF INSERT AS
BEGIN
   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@ROWCOUNT due to merge behavior that 
   --sets @@ROWCOUNT to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
	  INSERT INTO TestIdentity(Value)
         SELECT Value
         FROM   inserted;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

          --[Error logging section]
          DECLARE @ERROR_NUMBER int = ERROR_NUMBER(),
                  @ERROR_PROCEDURE sysname = ERROR_PROCEDURE(),
                  @ERROR_MESSAGE varchar(4000) = ERROR_MESSAGE();
          EXEC ErrorHandling.ErrorLog$Insert 
                          @ERROR_NUMBER,@ERROR_PROCEDURE,@ERROR_MESSAGE;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH;
END;
GO

INSERT INTO Example.TestIdentity(Value)
VALUES ('with trigger');

SELECT SCOPE_IDENTITY() AS NewTestIdentityId;
GO

INSERT INTO Example.TestIdentity(Value)
VALUES ('with trigger two');

SELECT testIdentityId AS NewTestIdentityId 
FROM   Example.TestIdentity
WHERE  value = 'with trigger two'; --use an alternate key
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Triggers On Memory Optimized Tables
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

ALTER DATABASE AppendixB ADD FILEGROUP AppendixB_MemoryOptimized 
                                      CONTAINS MEMORY_OPTIMIZED_DATA;
GO
ALTER DATABASE AppendixB ADD FILE ( 
                          NAME = N'v_MemoryOptimized', 
                          FILENAME = N'C:\temp\AppendixB_MemoryOptimized' 
                                 ) TO FILEGROUP AppendixB_MemoryOptimized;

GO
CREATE SCHEMA Example_InMem;
GO

--this is the “transaction” table 
CREATE TABLE Example_InMem.AfterTriggerExample
(
    AfterTriggerExampleId  int  
         CONSTRAINT PKAfterTriggerExample PRIMARY KEY NONCLUSTERED,
    GroupingValue          varchar(10) NOT NULL,
    Value                  int NOT NULL
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
GO

--this is the table that holds the summary data
CREATE TABLE Example_InMem.AfterTriggerExampleGroupBalance
(
     GroupingValue  varchar(10) NOT NULL 
         CONSTRAINT PKAfterTriggerExampleGroupBalance 
                                PRIMARY KEY NONCLUSTERED,
        Balance int NOT NULL
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
GO


CREATE TYPE Example_InMem.AfterTriggerExampleIntermediateSet AS TABLE(
    GroupingValue varchar(10) NULL,   
    NewBalance int NULL,
    INDEX TT_AfterTriggerExampleIntermediateSet NONCLUSTERED  
    (
	    GroupingValue,
	    NewBalance
    )
)
WITH ( MEMORY_OPTIMIZED = ON );
GO


CREATE TRIGGER Example_InMem.AfterTriggerExample$InsertTrigger
ON Example_InMem.AfterTriggerExample
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT 
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = REPEATABLE READ, 
                   LANGUAGE = N'us_english')
   --use inserted for insert or update trigger, deleted for update 
   --or delete trigger count instead of @@ROWCOUNT due to merge behavior 
   --that sets @@ROWCOUNT to a number that is equal to number of merged 
   --rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --Natively compiled objects can't be the target of a MERGE currently, 
   --so could use @@ROWCOUNT, but this is safer for the future
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --      @rowsAffected int = (SELECT COUNT(*) FROM deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
     --[validation section] 
     --Use a WHERE EXISTS to inserted to make sure not to duplicate 
     --rows in the set if > 1 row is modified for the same grouping value

     DECLARE @Exists BIT --can't use subquery, so use this to set 
                         --a value if a row exists
     SELECT @Exists = 1
     FROM   Example_InMem.AfterTriggerExample
     WHERE  EXISTS (SELECT 1 --select * prohibited
                    FROM Inserted 
                    WHERE  AfterTriggerExample.GroupingValue = 
                                             Inserted.Groupingvalue)
     GROUP  BY AfterTriggerExample.GroupingValue
     HAVING SUM(Value) < 0

     IF @Exists = 1 --replaces the subquery
           BEGIN
             IF @rowsAffected = 1
                 SELECT @msg = 'Grouping Value "' + GroupingValue + 
                   '" balance value after operation must be greater than 0'
                 FROM   inserted;
           ELSE
                 SELECT @msg = 'The total for the grouping value must ' +
                                               'be greater than 0';
                 THROW  50000, @msg, 16;
           END;
                         
           --[modification section]

          --get the balance for any Grouping Values used in the DML 
          --statement temp table to loop through
          DECLARE @GroupBalance 
                       Example_InMem.AfterTriggerExampleIntermediateSet

          --set up the set of balances to modify
          INSERT INTO @GroupBalance (GroupingValue, NewBalance)
          SELECT  ChangedRows.GroupingValue, SUM(Value) AS NewBalance
          FROM    ( --Only one row per grouping set                                        
                    SELECT  DISTINCT GroupingValue                                   
                    FROM   Inserted 
                   ) as ChangedRows
             JOIN Example_InMem.AfterTriggerExample
                ON AfterTriggerExample.GroupingValue = 
                                             ChangedRows.GroupingValue
            GROUP  BY ChangedRows.GroupingValue;

          DECLARE @GroupingValue varchar(10), 
                  @NewBalance int, @ContinueLoop int = 1;
          
          -- Prehistoric cursor, grab a value from temp table, use it,
          -- delete it from temp table, get another. 
          -- Can’t use BREAK so we start by fetching one value first
          SELECT TOP(1) @GroupingValue = GroupingValue, 
                        @NewBalance = NewBalance
          FROM   @GroupBalance;

          WHILE (@ContinueLoop=1)
            BEGIN
                --update the row if it exists, if it doesn’t the @@ROWCOUNT 
                --will signal insert
                UPDATE Example_InMem.AfterTriggerExampleGroupBalance
                SET    Balance = @NewBalance
               WHERE @GroupingValue = GroupingValue
                   AND @NewBalance IS NOT NULL;

               IF @@ROWCOUNT = 0 
                 INSERT INTO Example_InMem.AfterTriggerExampleGroupBalance 
                                                   (GroupingValue, Balance)
                    VALUES (@GroupingValue, @NewBalance);

                --Manage loop variables
                DELETE FROM @GroupBalance 
                WHERE @GroupingValue = GroupingValue;

                SELECT TOP(1) @GroupingValue = GroupingValue, 
                              @NewBalance = NewBalance
                FROM   @GroupBalance;
                
                IF @@ROWCOUNT = 0 SET @ContinueLoop = 0; 
            END
   END TRY
   BEGIN CATCH
      
      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END;
GO


CREATE TRIGGER [Example_InMem].[AfterTriggerExample$UpdateTrigger]
ON [Example_InMem].[AfterTriggerExample]
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE 
AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = REPEATABLE READ, LANGUAGE = N'us_english')

   --use inserted for insert or update trigger, deleted for update 
   --or delete trigger count instead of @@ROWCOUNT due to merge behavior 
   --that sets @@ROWCOUNT to a number that is equal to number of merged 
   --rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --Natively compiled objects can't be the target of a MERGE, 
   --so could use @@ROWCOUNT
   @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --  @rowsAffected int = (SELECT COUNT(*) FROM deleted);
   
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
      --[validation section] 
      --Use a WHERE EXISTS to inserted to make sure not to duplicate 
      --rows in the set if > 1 row is modified for the same grouping value

      DECLARE @Exists BIT 
      SELECT @Exists = 1
      FROM   Example_InMem.AfterTriggerExample
 
      /*************************************************************
       --added UNION ALL and the deleted part
       *************************************************************/
      WHERE  EXISTS (SELECT 1                                                                           
                     FROM   Inserted 
                     WHERE  AfterTriggerExample.GroupingValue =                                                         
                                            Inserted.GroupingValue
                      UNION ALL
                      SELECT 1
                      FROM   Deleted
                      WHERE  AfterTriggerExample.GroupingValue = 
                                             Deleted.Groupingvalue)
            GROUP  BY AfterTriggerExample.GroupingValue
            HAVING SUM(Value) < 0;

       IF @Exists = 1
         BEGIN
               IF @rowsAffected = 1
                    SELECT @msg = 'Grouping Value "' + GroupingValue + 
                   '" balance value after operation must be greater than 0'
                         FROM   inserted;
               ELSE
                   SELECT @msg = 'The total for the grouping value must ' +
                                                       'be greater than 0';
                   THROW  50000, @msg, 16;
          END;
                        
      --[modification section]
      --get the balance for any Grouping Values used in the DML statement
      DECLARE @GroupBalance 
                        Example_InMem.AfterTriggerExampleIntermediateSet;

      INSERT INTO @GroupBalance (GroupingValue, NewBalance)
      SELECT  ChangedRows.GroupingValue, SUM(Value) AS NewBalance
      FROM    (SELECT  GroupingValue --now also need deleted rows                                                                         
               FROM   Inserted 
               UNION --need distinct values, from inserted and deleted
               SELECT GroupingValue
               FROM   Deleted
               ) as ChangedRows
            --left outer join, because the primary key could change,
            --looking like a delete of all rows
             LEFT OUTER JOIN Example_InMem.AfterTriggerExample
                ON AfterTriggerExample.GroupingValue = 
                                           ChangedRows.GroupingValue
       GROUP  BY ChangedRows.GroupingValue;

       DECLARE @GroupingValue varchar(10), @NewBalance int, 
               @ContinueLoop int = 1;
          
       SELECT TOP(1) @GroupingValue = GroupingValue, 
                     @NewBalance = NewBalance
       FROM   @GroupBalance;

       WHILE (@ContinueLoop=1 )
         BEGIN

             UPDATE Example_InMem.AfterTriggerExampleGroupBalance
             SET    Balance = @NewBalance
             WHERE @GroupingValue = GroupingValue
               --If no rows for GroupingValue, balance NULL
                AND @NewBalance IS NOT NULL; 

             --null balance is a delete
             IF @@ROWCOUNT = 0 and @NewBalance IS NOT NULL 
                 INSERT INTO 
                   Example_InMem.AfterTriggerExampleGroupBalance 
                                         (GroupingValue, Balance)
                 VALUES (@GroupingValue, @NewBalance);
                
             --this means no rows for grouping, then delete       
             IF @NewBalance IS NULL 
                 DELETE FROM 
                        Example_InMem.AfterTriggerExampleGroupBalance
                 WHERE  @GroupingValue = GroupingValue;

                 --Manage loop variables
                 DELETE FROM @GroupBalance 
                 WHERE @GroupingValue = GroupingValue;

                 SELECT TOP(1) @GroupingValue = GroupingValue, 
                               @NewBalance = NewBalance
                 FROM   @GroupBalance;

                 IF @@ROWCOUNT = 0 SET @ContinueLoop = 0; 

              END;
   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END;
GO

