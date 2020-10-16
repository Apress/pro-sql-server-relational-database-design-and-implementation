--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
exit
----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Using DDL to Create the Database
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Creating the Database
--*****
----------------------------------------------------------------------------------------------------------


CREATE DATABASE ConferenceMessaging; 
GO

SELECT type_desc, size * 8 / 1024 AS size_MB, physical_name
FROM   sys.master_files
WHERE  database_id = DB_ID('ConferenceMessaging');
GO

USE ConferenceMessaging;

DROP TABLE IF EXISTS Attendees.UserConnection, Messages.MessageTopic,Messages.Topic,Messages.Message, Attendees.MessagingUser,Attendees.AttendeeType;
DROP SEQUENCE IF EXISTS Messages.TopicIdGenerator;
GO

DROP SCHEMA IF EXISTS Attendees;
DROP SCHEMA IF EXISTS Messages;
GO

--determine the login that is linked to the dbo user in the database
SELECT  SUSER_SNAME(sid) AS databaseOwner
FROM    sys.database_principals
WHERE   name = 'dbo';
GO

--Get the login of owner of the database from all database
SELECT SUSER_SNAME(owner_sid) AS databaseOwner, name
FROM   sys.databases;
GO

ALTER AUTHORIZATION ON DATABASE::ConferenceMessaging TO SA;

--Get the login of owner of the database from all database
SELECT SUSER_SNAME(owner_sid) AS databaseOwner, name
FROM   sys.databases;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Creating the Basic Table Structures
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Schema
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Messages; --tables pertaining to the messages being sent
GO
CREATE SCHEMA Attendees; --tables pertaining to the attendees 
                         --and how they can send messages
GO

SELECT name, USER_NAME(principal_id) AS principal
FROM   sys.schemas
WHERE  name <> USER_NAME(principal_id); --don't list user schemas
GO

ALTER AUTHORIZATION ON SCHEMA::Messages TO dbo;
GO

----------------------------------------------------------------------------------------------------------
--Columns and Base Datatypes
----------------------------------------------------------------------------------------------------------

DECLARE @pointInTime datetime2(0);
SET @pointInTime = SYSDATETIME();

SELECT DATEADD(HOUR,DATEPART(HOUR,@pointInTime),
                CAST(CAST(@PointInTime AS date) AS datetime2(0)) ) 

----------------------------------------------------------------------------------------------------------
--NULL Specification
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA DemoNull;
GO
CREATE TABLE DemoNull.ComputedColumn
(
     BaseColumn int NULL,
     ComputedColumn AS BaseColumn PERSISTED NOT NULL
);
GO

INSERT INTO DemoNull.ComputedColumn(BaseColumn)
VALUES (1);
GO

INSERT INTO DemoNull.ComputedColumn(BaseColumn)
VALUES (NULL);
GO

DROP TABLE IF EXISTS DemoNull.ComputedColumn;
DROP SCHEMA IF EXISTS DemoNull;
GO

----------------------------------------------------------------------------------------------------------
--Managing Non-Natural Primary Keys
----------------------------------------------------------------------------------------------------------

--
--Generation using the IDENTITY Property
--

--
--Automatically Generation, Programmatically Applied Value
--

CREATE SEQUENCE Messages.TopicIdGenerator
AS INT    
MINVALUE 10000 --starting value
NO MAXVALUE --technically will max out at max int
START WITH 10000 --value where the sequence will start, 
                 --differs from min based on cycle property
INCREMENT BY 1 --number that is added the previous value
NO CYCLE   --if setting is cycle, when it reaches max value it starts over
CACHE 100; --Use adjust number of values that SQL Server caches. 
           --Cached values would be lost if the server is restarted, 
           --but keeping them in RAM makes access faster;
GO

SELECT NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId;
SELECT NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId;
GO

SELECT NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId,
       NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId2,
	   NEXT VALUE FOR Messages.TopicIdGenerator AS TopicId3;
GO

--To start a certain number add WITH <starting value literal>
ALTER SEQUENCE Messages.TopicIdGenerator RESTART;  
GO


DECLARE @range_first_value sql_variant, @range_last_value sql_variant,
        @sequence_increment sql_variant;

EXEC sp_sequence_get_range @sequence_name = N'Messages.TopicIdGenerator' 
     , @range_size = 100
     , @range_first_value = @range_first_value OUTPUT 
     , @range_last_value = @range_last_value OUTPUT 
     , @sequence_increment = @sequence_increment OUTPUT;

SELECT CAST(@range_first_value AS int) AS FirstTopicId, 
       CAST(@range_last_value AS int) AS LastTopicId, 
       CAST(@sequence_increment AS int) AS Increment;
GO

SELECT start_value, increment, current_value
FROM sys.sequences 
WHERE SCHEMA_NAME(schema_id) = 'Messages'
   AND name = 'TopicIdGenerator';

----------------------------------------------------------------------------------------------------------
--The Actual DDL to Build Tables
----------------------------------------------------------------------------------------------------------
--Make the tables able to be dropped and recreated in our test scenario
DROP TABLE IF EXISTS Attendees.UserConnection,
                     Messages.MessageTopic,
                     Messages.Topic,
                     Messages.Message,                     
                     Attendees.AttendeeType, 
                     Attendees.MessagingUser;
--create all of the objects
CREATE TABLE Attendees.AttendeeType ( 
        AttendeeType         varchar(20)  NOT NULL ,
        Description          varchar(60)  NOT NULL 
);
--As this is a non-editable table, we load the data here to
--start with as part of the create script
INSERT INTO Attendees.AttendeeType
VALUES ('Regular', 'Typical conference attendee'),
       ('Speaker', 'Person scheduled to speak'),
       ('Administrator','Manages System');

CREATE TABLE Attendees.MessagingUser ( 
        MessagingUserId      int NOT NULL IDENTITY ( 1,1 ) ,
        UserHandle           varchar(20)  NOT NULL ,
        AccessKeyValue       char(10)  NOT NULL ,
        AttendeeNumber       char(8)  NOT NULL ,
        FirstName            nvarchar(50)  NULL ,
        LastName             nvarchar(50)  NULL ,
        AttendeeType         varchar(20)  NOT NULL ,
        DisabledFlag         bit  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Attendees.UserConnection
( 
        UserConnectionId     int NOT NULL IDENTITY ( 1,1 ) ,
        ConnectedToMessagingUserId int  NOT NULL ,
        MessagingUserId      int  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Messages.Message ( 
        MessageId            int NOT NULL IDENTITY ( 1,1 ) ,
        RoundedMessageTime  as 
            (DATEADD(hour,DATEPART(hour,MessageTime),
             CAST(CAST(MessageTime AS date) AS datetime2(0)) )) 
                                     PERSISTED NOT NULL,
        SentToMessagingUserId int  NULL ,
        MessagingUserId      int  NOT NULL ,
        Text                 nvarchar(200)  NOT NULL ,
        MessageTime          datetime2(0)  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);
CREATE TABLE Messages.MessageTopic ( 
        MessageTopicId       int NOT NULL IDENTITY ( 1,1 ) ,
        MessageId            int  NOT NULL ,
        UserDefinedTopicName nvarchar(30)  NULL ,
        TopicId              int  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);

CREATE TABLE Messages.Topic ( 
        TopicId int NOT NULL 
           CONSTRAINT DFLTTopic_TopicId 
               DEFAULT(NEXT VALUE FOR  Messages.TopicIdGenerator),
        TopicName            nvarchar(30)  NOT NULL ,
        Description          varchar(60)  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);

----------------------------------------------------------------------------------------------------------
--*****
--Adding Uniqueness Constraints
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Adding Primary Key Constraints
----------------------------------------------------------------------------------------------------------

ALTER TABLE Attendees.AttendeeType
     ADD CONSTRAINT PKAttendeeType PRIMARY KEY CLUSTERED (AttendeeType);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT PKMessagingUser 
             PRIMARY KEY CLUSTERED (MessagingUserId);

ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT PKUserConnection 
             PRIMARY KEY CLUSTERED (UserConnectionId);

ALTER TABLE Messages.Message
     ADD CONSTRAINT PKMessage PRIMARY KEY CLUSTERED (MessageId);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT PKMessageTopic PRIMARY KEY CLUSTERED (MessageTopicId);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT PKTopic PRIMARY KEY CLUSTERED (TopicId);
GO


CREATE TABLE dbo.TestConstraintName 
(
   TestConstraintNameId int PRIMARY KEY
);
GO
SELECT constraint_name
FROM information_schema.table_constraints
WHERE  table_schema = 'dbo'
  AND  table_name = 'TestConstraintName';
GO
DROP TABLE dbo.TestConstraintName;

----------------------------------------------------------------------------------------------------------
--Adding UNIQUE Constraints
----------------------------------------------------------------------------------------------------------

ALTER TABLE Messages.Message
     ADD CONSTRAINT AKMessage_TimeUserAndText UNIQUE
      (RoundedMessageTime, MessagingUserId, Text);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT AKTopic_Name UNIQUE (TopicName);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT AKMessageTopic_TopicAndMessage UNIQUE
      (MessageId, TopicId, UserDefinedTopicName);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AKMessagingUser_UserHandle UNIQUE (UserHandle);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AKMessagingUser_AttendeeNumber UNIQUE
     (AttendeeNumber);

ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT AKUserConnection_Users UNIQUE
     (MessagingUserId, ConnectedToMessagingUserId);
GO

----------------------------------------------------------------------------------------------------------
--What about Indexes?
----------------------------------------------------------------------------------------------------------

SELECT CONCAT(OBJECT_SCHEMA_NAME(object_id),'.',
              OBJECT_NAME(object_id)) AS object_name,
              name as index_name, is_primary_key as PK, 
              is_unique_constraint as UQ
FROM   sys.indexes
WHERE  OBJECT_SCHEMA_NAME(object_id) <> 'sys'
  AND  (is_primary_key = 1 
        OR is_unique_constraint = 1)
ORDER BY object_name, is_primary_key DESC, name;

----------------------------------------------------------------------------------------------------------
--*****
--Building DEFAULT Constraints
--*****
----------------------------------------------------------------------------------------------------------
ALTER TABLE Attendees.MessagingUser
   ADD CONSTRAINT DFLTMessagingUser_DisabledFlag
   DEFAULT (0) FOR DisabledFlag;
GO

SELECT CONCAT('ALTER TABLE ',TABLE_SCHEMA,'.',TABLE_NAME,CHAR(13),CHAR(10),
               '    ADD CONSTRAINT DFLT', TABLE_NAME, '_' ,
               COLUMN_NAME, CHAR(13), CHAR(10),
       '    DEFAULT (SYSDATETIME()) FOR ', COLUMN_NAME,';')
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  COLUMN_NAME in ('RowCreateTime', 'RowLastUpdateTime')
  and  TABLE_SCHEMA in ('Messages','Attendees')
ORDER BY TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME;
GO

ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTMessagingUser_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Attendees.MessagingUser
    ADD CONSTRAINT DFLTMessagingUser_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTUserConnection_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Attendees.UserConnection
    ADD CONSTRAINT DFLTUserConnection_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessage_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.Message
    ADD CONSTRAINT DFLTMessage_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessageTopic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.MessageTopic
    ADD CONSTRAINT DFLTMessageTopic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;

ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTTopic_RowCreateTime
    DEFAULT (SYSDATETIME()) FOR RowCreateTime;

ALTER TABLE Messages.Topic
    ADD CONSTRAINT DFLTTopic_RowLastUpdateTime
    DEFAULT (SYSDATETIME()) FOR RowLastUpdateTime;
GO
----------------------------------------------------------------------------------------------------------
--*****
--Adding Relationships (Foreign Keys)
--*****
----------------------------------------------------------------------------------------------------------
ALTER TABLE Attendees.MessagingUser  
    ADD  CONSTRAINT FKMessagingUser$IsSent$Messages_Message 
            FOREIGN KEY(AttendeeType)
            REFERENCES Attendees.AttendeeType (AttendeeType)
ON UPDATE CASCADE
ON DELETE NO ACTION;
GO


ALTER TABLE Attendees.UserConnection
        ADD CONSTRAINT 
          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) 
              REFERENCES Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE CASCADE;

ALTER TABLE Attendees.UserConnection
        ADD CONSTRAINT 
          FKMessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
        FOREIGN KEY  (ConnectedToMessagingUserId) 
                 REFERENCES Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE CASCADE;
GO

ALTER TABLE Attendees.UserConnection
        DROP CONSTRAINT IF EXISTS
          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection;
GO

ALTER TABLE Attendees.UserConnection
        ADD CONSTRAINT 
          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) 
                REFERENCES Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;

ALTER TABLE Attendees.UserConnection
        ADD CONSTRAINT 
          FKMessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
        FOREIGN KEY  (ConnectedToMessagingUserId) 
               REFERENCES Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;
GO

CREATE TRIGGER MessagingUser$InsteadOfDeleteTrigger
ON Attendees.MessagingUser
INSTEAD OF DELETE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for 
   --update or delete trigger count instead of @@rowcount due to merge 
   --behavior that sets @@rowcount to a number that is equal to number of
   --merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]

          --implement multi-path cascade delete in trigger
          DELETE FROM Attendees.UserConnection 
          WHERE  MessagingUserId IN (SELECT MessagingUserId FROM DELETED);

          DELETE FROM Attendees.UserConnection 
          WHERE  ConnectedToMessagingUserId IN (SELECT MessagingUserId 
                                                FROM DELETED);

          --<perform action>
          DELETE FROM Attendees.MessagingUser 
          WHERE  MessagingUserId IN (SELECT MessagingUserId FROM DELETED);
   END TRY
   BEGIN CATCH
          IF @@trancount > 0
              ROLLBACK TRANSACTION;
          THROW;
     END CATCH;
END;
GO


ALTER TABLE Messages.Message
   ADD CONSTRAINT FKMessagingUser$Sends$Messages_Message FOREIGN KEY 
     (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;

ALTER TABLE Messages.Message
   ADD CONSTRAINT FKMessagingUser$IsSent$Messages FOREIGN KEY 
     (SentToMessagingUserId) REFERENCES 
                                   Attendees.MessagingUser(MessagingUserId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;
GO

ALTER TABLE Messages.MessageTopic
        ADD CONSTRAINT 
           FKTopic$CategorizesMessagesVia$Messages_MessageTopic FOREIGN KEY 
             (TopicId) REFERENCES Messages.Topic(TopicId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;
GO

ALTER TABLE Messages.MessageTopic
        ADD CONSTRAINT FKMessage$isCategorizedVia$MessageTopic FOREIGN KEY 
            (MessageId) REFERENCES Messages.Message(MessageId)
        ON UPDATE NO ACTION
        ON DELETE NO ACTION;
GO

----------------------------------------------------------------------------------------------------------
--Composite FOREIGN KEY Constraints AND NULL values
----------------------------------------------------------------------------------------------------------
--table with a compound key 
CREATE TABLE dbo.TwoPartKey
(
	Column1 int NOT NULL,
	Column2 int NOT NULL,
	CONSTRAINT PKTwoPartKey 
	  PRIMARY KEY (Column1,Column2)
);
--a row to reference
INSERT INTO dbo.TwoPartKey(Column1, Column2)
VALUES(1,1);

--table that references the two part key
CREATE TABLE dbo.TwoPartReference
(
	TwoPartReferenceId int NOT NULL 
	     CONSTRAINT PKTwoPartReference PRIMARY KEY,
	CONSTRAINT FKTwoPartReference$references$TwoPartKey
	   FOREIGN KEY (Column1, Column2) REFERENCES
		  dbo.TwoPartKey (Column1,Column2),
	Column1 int NULL,
	Column2 int NULL
);
GO

INSERT INTO dbo.TwoPartReference(TwoPartReferenceId, Column1, Column2)
VALUES(1,1,1);
GO

--causes error
INSERT INTO dbo.TwoPartReference(TwoPartReferenceId, Column1, Column2)
VALUES(2,1,2);
GO

--does not cause error
INSERT INTO dbo.TwoPartReference(TwoPartReferenceId, Column1, Column2)
VALUES(3,237209334,NULL);
GO

SELECT *
FROM dbo.TwoPartReference;
GO


DROP TABLE IF EXISTS dbo.TwoPartReference, dbo.TwoPartKey;

----------------------------------------------------------------------------------------------------------
--*****
--Adding Basic CHECK Constraints
--*****
----------------------------------------------------------------------------------------------------------
ALTER TABLE Messages.Topic
   ADD CONSTRAINT CHKTopic_TopicName_NotEmpty
       CHECK (LEN(TRIM(TopicName)) > 0); --NOTE: TRIM introduced in 2017 
                                       --Use RTRIM(LTRIM in earler versions


ALTER TABLE Messages.MessageTopic
   ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NotEmpty
       CHECK (LEN(TRIM(UserDefinedTopicName)) > 0);
GO

ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
     CHECK (LEN(TRIM(UserHandle)) >= 5 
             AND TRIM(UserHandle) LIKE '[a-z]' +
                      REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));
--Note, this REPLICATE expresion only works as is for case 
--insensitive collation, more ranges needed for case sensitive ones
--and you could use an accent sensitive collaton if you wanted to include
--accented characters.
GO

INSERT INTO Messages.Topic(TopicId, TopicName, Description)
VALUES (0,'User Defined','User Enters Their Own User Defined Topic');
GO

ALTER TABLE Messages.MessageTopic
  ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NullUnlessUserDefined
   CHECK ((UserDefinedTopicName IS NULL and TopicId <> 0)
              OR (TopicId = 0 AND UserDefinedTopicName IS NOT NULL));

----------------------------------------------------------------------------------------------------------
--*****
--Triggers to Maintain Automatic Values
--*****
----------------------------------------------------------------------------------------------------------
CREATE TRIGGER MessageTopic$InsteadOfInsertTrigger
ON Messages.MessageTopic
INSTEAD OF INSERT AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
      --[validation section]
      --[modification section]
      --<perform action>
     INSERT INTO Messages.MessageTopic (MessageId, UserDefinedTopicName,
                              TopicId,RowCreateTime,RowLastUpdateTime)
     SELECT MessageId, UserDefinedTopicName, TopicId, 
            SYSDATETIME(), SYSDATETIME()
     FROM   inserted ;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH;
 END;
GO

CREATE TRIGGER Messages.MessageTopic$InsteadOfUpdateTrigger
ON Messages.MessageTopic
INSTEAD OF UPDATE AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
          --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
         UPDATE MessageTopic 
          SET   MessageId = Inserted.MessageId,
                UserDefinedTopicName = Inserted.UserDefinedTopicName,
                TopicId = Inserted.TopicId,
                --no changes allowed
                RowCreateTime = MessageTopic.RowCreateTime, 
                RowLastUpdateTime = SYSDATETIME()
          FROM  inserted 
                   JOIN Messages.MessageTopic 
                       ON inserted.MessageTopicId =  
                                       MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@TRANCOUNT > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH;
  END;
GO


/*
CREATE TRIGGER MessageTopic$InsertRowControlsTrigger
ON Messages.MessageTopic
AFTER INSERT AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
      --[validation section]
      --[modification section]
     UPDATE Messages.MessageTopic 
     SET    RowCreateTime = SYSDATETIME(),
            RowLastUpdateTime = SYSDATETIME()
     FROM   inserted
		 JOIN Messages.MessageTopic
                ON inserted.MessageTopicId = MessageTopic.MessageTopicId 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH;
 END;
GO

CREATE TRIGGER MessageTopic$UpdateRowControlsTrigger
ON Messages.MessageTopic
AFTER UPDATE AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or 
   --delete trigger count instead of @@rowcount due to merge behavior that 
   --sets @@rowcount to a number that is equal to number of merged rows, 
   --not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
      --[validation section]
      --[modification section]
     UPDATE Messages.MessageTopic 
     SET    RowCreateTime = deleted.RowCreateTime,
            RowLastUpdateTime = SYSDATETIME()
     FROM   inserted
		 JOIN deleted
                ON inserted.MessageTopicId = deleted.MessageTopicId 
		 JOIN Messages.MessageTopic
                ON inserted.MessageTopicId = MessageTopic.MessageTopicId 
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

    END CATCH;
 END;
*/


**ADD triggers that ARE missing**

----------------------------------------------------------------------------------------------------------
--*****
--Documenting your Database
--*****
----------------------------------------------------------------------------------------------------------

--Messages schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Messaging objects',
   @level0type = 'Schema', @level0name = 'Messages';

--Messages.Topic table
EXEC sp_addextendedproperty @name = 'Description',
   @value = ' Pre-defined topics for messages',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic';

--Messages.Topic.TopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a Topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'TopicId';

--Messages.Topic.Name
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name of the topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'TopicName';

--Messages.Topic.Description
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Description of the purpose and utilization of the topics',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'Description';

--Messages.Topic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Topic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Topic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';

GO


SELECT objname, value
FROM   sys.fn_listExtendedProperty ( 'Description',
                                     'Schema','Messages',
                                     'Table','Topic',
                                      'Column',null);

** GET the rest OF the extended properties **

----------------------------------------------------------------------------------------------------------
--*****
--Viewing the Basic System Metadata
--*****
----------------------------------------------------------------------------------------------------------

SELECT SCHEMA_NAME, SCHEMA_OWNER
FROM   INFORMATION_SCHEMA.SCHEMATA
WHERE  SCHEMA_NAME <> SCHEMA_OWNER;
GO

SELECT table_schema + '.' + TABLE_NAME as TABLE_NAME, COLUMN_NAME, 
             --types that have a character or binary length
        case WHEN DATA_TYPE IN ('varchar','char','nvarchar',
                                'nchar','varbinary')
             THEN DATA_TYPE + CASE WHEN character_maximum_length = -1 
                                   THEN '(max)'
                                   ELSE '(' 
                                   + CAST(character_maximum_length as 
                                                   varchar(4)) + ')' END
                 --types with a datetime precision
                 WHEN DATA_TYPE IN ('time','datetime2','datetimeoffset')
                      THEN DATA_TYPE + 
                         '(' + CAST(DATETIME_PRECISION as varchar(4)) + ')'
                --types with a precision/scale
                 WHEN DATA_TYPE IN ('numeric','decimal')
                      THEN DATA_TYPE 
                       + '(' + CAST(NUMERIC_PRECISION as varchar(4)) + ','                
                             + CAST(NUMERIC_SCALE as varchar(4)) +  ')'
                 --timestamp should be reported as rowversion
                 WHEN DATA_TYPE = 'timestamp' THEN 'rowversion'
                 --and the rest. Note, float is declared with a bit length, 
                 --but is represented as either float or real in types 
                 else DATA_TYPE END AS DECLARED_DATA_TYPE,
        COLUMN_DEFAULT
FROM   INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_SCHEMA, TABLE_NAME,ORDINAL_POSITION;
GO

SELECT TABLE_SCHEMA, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM   INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE  CONSTRAINT_SCHEMA IN ('Attendees','Messages')
ORDER  BY  CONSTRAINT_SCHEMA, TABLE_NAME;
GO

SELECT OBJECT_SCHEMA_NAME(parent_id) + '.' 
                             + OBJECT_NAME(parent_id) AS TABLE_NAME, 
           name AS TRIGGER_NAME, 
           CASE WHEN is_instead_of_trigger = 1 
                   THEN 'INSTEAD OF' 
           ELSE 'AFTER' END AS TRIGGER_FIRE_TYPE
FROM   sys.triggers
WHERE  type_desc = 'SQL_TRIGGER' --not a clr trigger
    --DML trigger on a table or view
  AND  parent_class_desc = 'OBJECT_OR_COLUMN' 
ORDER BY TABLE_NAME, TRIGGER_NAME;
GO
SELECT  TABLE_SCHEMA + '.' + TABLE_NAME AS TABLE_NAME,
        TABLE_CONSTRAINTS.CONSTRAINT_NAME, CHECK_CLAUSE,*
FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS
            JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS
               ON TABLE_CONSTRAINTS.CONSTRAINT_SCHEMA = 
                                CHECK_CONSTRAINTS.CONSTRAINT_SCHEMA
                  AND TABLE_CONSTRAINTS.CONSTRAINT_NAME = 
                                 CHECK_CONSTRAINTS.CONSTRAINT_NAME;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Unit Testing Your Structures
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT *
               FROM  sys.check_constraints
			   WHERE OBJECT_SCHEMA_NAME(check_constraints.parent_object_id) = 'Messages'
			     AND sys.check_constraints.name = 'CHKTopic_TopicName_NotEmpty'
			     AND  check_constraints.definition = '(len(Trim([TopicName]))>(0))'
				 AND check_constraints.is_disabled = 0)
 THROW 50000,'Check constraint CHKTopic_TopicName_NotEmpty does not exist or is disabled',1;
 GO


SET NOCOUNT ON;
USE ConferenceMessaging;
GO
DELETE FROM Messages.MessageTopic ;
DELETE FROM Messages.Message;
DELETE FROM Messages.Topic WHERE TopicId <> 0; --Leave the User Defined Topic
DELETE FROM Attendees.UserConnection;
DELETE FROM Attendees.MessagingUser;
GO

DECLARE @TestName nvarchar(100) = 'Attendees.MessagingUser Single Row';
BEGIN TRY
	INSERT INTO [Attendees].[MessagingUser]
			   ([UserHandle],[AccessKeyValue],[AttendeeNumber]
			   ,[FirstName],[LastName],[AttendeeType]
			   ,[DisabledFlag])
	VALUES ('FredF','0000000000','00000000','Fred',
                                      'Flintstone','Regular',0);
END TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                                      '; ErrorNumber:',ERROR_NUMBER(),
                                      ' ErrorMessage:',ERROR_MESSAGE());
       THROW 50000, @msg,16;
END CATCH;
GO

DECLARE @TestName nvarchar(100) = 
            'Check CHKMessagingUser_UserHandle_LengthAndStart';
BEGIN TRY 
        INSERT INTO [Attendees].[MessagingUser]
                           ([UserHandle],[AccessKeyValue],[AttendeeNumber]
                           ,[FirstName],[LastName],[AttendeeType]
                           ,[DisabledFlag])
        VALUES ('Wil','0000000000','00000001','Wilma',
                                      'Flintstone','Regular',0);
        THROW 50000,'No error raised',1;
END TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                                '; ErrorNumber:',ERROR_NUMBER(),
                                ' ErrorMessage:',ERROR_MESSAGE());
        IF ERROR_MESSAGE() NOT LIKE 
                  '%CHKMessagingUser_UserHandle_LengthAndStart%'
           THROW 50000,@msg,1;
END CATCH;
GO


DECLARE @TestName nvarchar(100) = 
            'Check CHKMessagingUser_UserHandle_LengthAndStart';
BEGIN TRY --Check UserHandle Check Constraint
        INSERT INTO [Attendees].[MessagingUser]
                           ([UserHandle],[AccessKeyValue],[AttendeeNumber]
                           ,[FirstName],[LastName],[AttendeeType]
                           ,[DisabledFlag])
        VALUES ('Wilma@','0000000000','00000001',
                'Wilma','Flintstone','Regular',0);
        THROW 50000,'No error raised',1;
END TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                               '; ErrorNumber:',ERROR_NUMBER(),
                               ' ErrorMessage:',ERROR_MESSAGE());

        IF ERROR_MESSAGE() NOT LIKE 
             '%CHKMessagingUser_UserHandle_LengthAndStart%'
                THROW 50000,@msg,1;
END CATCH;
GO

DECLARE @TestName nvarchar(100) = 'Messages.Messages Single Insert';
BEGIN TRY
	INSERT INTO [Messages].[Message]
           ([MessagingUserId]
                   ,[SentToMessagingUserId]
           ,[Text]
           ,[MessageTime])
     VALUES
        ((SELECT MessagingUserId FROM Attendees.MessagingUser 
          WHERE UserHandle = 'FredF')
        ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
          WHERE UserHandle = 'WilmaF')
        ,'It looks like I will be late tonight'
         ,SYSDATETIME());
END TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                            '; ErrorNumber:',ERROR_NUMBER(),
                            ' ErrorMessage:',ERROR_MESSAGE());
       THROW 50000, @msg,16;
END CATCH;
GO

DECLARE @TestName nvarchar(100) = 'AKMessage_TimeUserAndText';
BEGIN TRY
  INSERT INTO [Messages].[Message]
                  ([MessagingUserId]
                   ,[SentToMessagingUserId]
                   ,[Text]
                   ,[MessageTime])
       VALUES
        --Row1
         ((SELECT MessagingUserId FROM Attendees.MessagingUser 
          WHERE UserHandle = 'FredF')
          ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'WilmaF')  --
           ,'It looks like I will be late tonight',SYSDATETIME()),

          --Row2
          ((SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'FredF')
           ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'WilmaF')  --
           ,'It looks like I will be late tonight',SYSDATETIME());
        THROW 50000,'No error raised',1;
END TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                          '; ErrorNumber:',ERROR_NUMBER(),
                          ' ErrorMessage:',ERROR_MESSAGE());
      IF ERROR_MESSAGE() NOT LIKE '%AKMessage_TimeUserAndText%'
		 THROW 50000, @msg,16;
END CATCH;
GO


DECLARE @TestName nvarchar(100) =       
          'CHKMessageTopic_UserDefinedTopicName_NullUnlessUserDefined';
--Usually the client would pass in these values
DECLARE @messagingUserId int, @text nvarchar(200), 
        @messageTime datetime2, @RoundedMessageTime datetime2(0);

SELECT @messagingUserId = (SELECT MessagingUserId 
                           FROM Attendees.MessagingUser
                           WHERE UserHandle = 'FredF'),
       @text = 'Oops Why Did I say That?', @messageTime = SYSDATETIME();

--uses same algorithm as the check constraint to calculate part of the key
SELECT @RoundedMessageTime = (
          DATEADD(HOUR,DATEPART(HOUR,@MessageTime),
               CONVERT(datetime2(0),CONVERT(date,@MessageTime))));

IF NOT EXISTS (SELECT * FROM  Messages.Topic WHERE TopicName = 'General Topic')
    INSERT INTO Messages.Topic(TopicName, Description)
    VALUES('General Topic','General Topic');

BEGIN TRY
   BEGIN TRANSACTION;
   --first create a new message
   INSERT INTO Messages.Message
            (MessagingUserId, SentToMessagingUserId, Text,MessageTime)
   VALUES (@messagingUserId,NULL,@text, @messageTime);

   --then insert the topic, but this will fail because General topic is not
   --compatible with a UserDefinedTopicName value
   INSERT INTO Messages.MessageTopic
                 (MessageId, TopicId, UserDefinedTopicName)
   VALUES(      (SELECT MessageId
                 FROM   Messages.Message
                 WHERE  MessagingUserId = @messagingUserId
                   AND  Text = @text
                   AND  RoundedMessageTime = @RoundedMessageTime),
                                     (SELECT TopicId
                                      FROM Messages.Topic 
                                      WHERE TopicName = 'General Topic'),
                                     'Stupid Stuff');
  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
	IF @@TRANCOUNT > 0
		ROLLBACK;

       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                          '; ErrorNumber:',ERROR_NUMBER(),
                          ' ErrorMessage:',ERROR_MESSAGE());
    IF ERROR_MESSAGE() NOT LIKE
             '%CHKMessageTopic_UserDefinedTopicName_NullUnlessUserDefined%'
         THROW 50000,@msg,1;
END CATCH;
