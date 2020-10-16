
/*
--need to pick the right location for your files. I am using e:\SQL Files\Data\ 
CREATE DATABASE ConferenceMessagingMemoryOptimized
GO

ALTER DATABASE [ConferenceMessagingMemoryOptimized] ADD FILEGROUP [ConferenceMessagingMemoryOptimized_MemoryOptimized] CONTAINS MEMORY_OPTIMIZED_DATA 
GO
ALTER DATABASE [ConferenceMessagingMemoryOptimized] ADD FILE ( NAME = N'ConferenceMessagingMemoryOptimized_MemoryOptimized', FILENAME = N'e:\SQL Files\Data\ConferenceMessagingMemoryOptimized_MemoryOptimized' ) TO FILEGROUP [ConferenceMessagingMemoryOptimized_MemoryOptimized]
GO
*/

USE ConferenceMessagingMemoryOptimized
GO
DROP TABLE IF EXISTS Attendees.UserConnection, Messages.MessageTopic,Messages.Topic,Messages.Message, Attendees.MessagingUser,Attendees.AttendeeType;
DROP SEQUENCE IF EXISTS Messages.TopicIdGenerator;
DROP TYPE IF EXISTS Base.Surrogate;
DROP FUNCTION IF EXISTS MemOptTools.String$CheckSimpleAlphaNumeric;
GO

DROP SCHEMA IF EXISTS MemOptTools;
DROP SCHEMA IF EXISTS Attendees;
DROP SCHEMA IF EXISTS Messages;
DROP SCHEMA IF EXISTS Base;
GO

CREATE SCHEMA Messages; --tables pertaining to the messages being sent
GO
CREATE SCHEMA Attendees; --tables pertaining to the attendees and how they can send messages
GO
ALTER AUTHORIZATION ON SCHEMA::Messages To DBO;
GO
ALTER AUTHORIZATION ON SCHEMA::Attendees To DBO;
GO

--CREATE SEQUENCE Messages.TopicIdGenerator
--AS INT    
--MINVALUE 10000 --starting value
--NO MAXVALUE --technically will max out at max int
--START WITH 10000 --value where the sequence will start, differs from min based on 
--             --cycle property
--INCREMENT BY 1 --number that is added the previous value
--NO CYCLE --if setting is cycle, when it reaches max value it starts over
--CACHE 100; --Use adjust number of values that SQL Server caches. Cached values would
--          --be lost if the server is restarted, but keeping them in RAM makes access faster;

--GO
CREATE TABLE Attendees.AttendeeType ( 
        AttendeeType         varchar(20)  NOT NULL ,
        Description          varchar(60)  NOT NULL ,
		CONSTRAINT PKAttendeeType 
			PRIMARY KEY NONCLUSTERED HASH (AttendeeType) WITH (BUCKET_COUNT=10)
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

--As this is a non-editable table, we load the data here to
--start with
INSERT INTO Attendees.AttendeeType
VALUES ('Regular', 'Typical conference attendee'),
           ('Speaker', 'Person scheduled to speak'),
           ('Administrator','Manages System');

CREATE TABLE Attendees.MessagingUser ( 
        MessagingUserId      int IDENTITY ( 1,1 ) ,
        UserHandle           varchar(20)  NOT NULL ,
        AccessKeyValue       char(10)  NOT NULL ,
        AttendeeNumber       char(8)  NOT NULL ,
        FirstName            nvarchar(50)  NULL ,
        LastName             nvarchar(50)  NULL ,
        AttendeeType         varchar(20)  NOT NULL ,
        DisabledFlag         bit  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL ,
		CONSTRAINT PKMessagingUser PRIMARY KEY NONCLUSTERED HASH (MessagingUserId) WITH (BUCKET_COUNT=10000)
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

/*
Note: rowversion/timestamp is not available to memory optimized tables. If you try to add one, you get:

Msg 10794, Level 16, State 88, Line 62
The type 'timestamp' is not supported with memory optimized tables.
*/

CREATE TABLE Attendees.UserConnection
( 
        UserConnectionId     int NOT NULL IDENTITY ( 1,1 ) ,
        ConnectedToMessagingUserId int  NOT NULL ,
        MessagingUserId      int  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL ,
		CONSTRAINT PKUserConnection PRIMARY KEY NONCLUSTERED HASH (UserConnectionId) WITH (BUCKET_COUNT=10000)
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

CREATE TABLE Messages.Message ( 
        MessageId            int NOT NULL IDENTITY ( 1,1 ) ,
        
		--allowed in 2017 and later
        RoundedMessageTime as (dateadd(hour,datepart(hour,MessageTime),
                                       CAST(CAST(MessageTime as date)as datetime2(0)) ))
                                       PERSISTED,
        SentToMessagingUserId int  NULL ,
        MessagingUserId      int  NOT NULL ,
        Text                 nvarchar(200)  NOT NULL ,
        MessageTime          datetime2(0)  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL ,
		CONSTRAINT PKMessage PRIMARY KEY NONCLUSTERED HASH (MessageId) WITH (BUCKET_COUNT=10000)
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

CREATE TABLE Messages.MessageTopic ( 
        MessageTopicId       int NOT NULL IDENTITY ( 1,1 ) ,
        MessageId            int  NOT NULL ,
        UserDefinedTopicName nvarchar(30)  NULL ,
        TopicId              int  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL,
		CONSTRAINT PKMessageTopic PRIMARY KEY NONCLUSTERED HASH (MessageTopicId) WITH (BUCKET_COUNT=10000) 
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);

CREATE TABLE Messages.Topic ( 
        --TopicId int NOT NULL CONSTRAINT DFLTTopic_TopicId 
        --                        DEFAULT(NEXT VALUE FOR  Messages.TopicIdGenerator),
		TopicId int NOT NULL IDENTITY(1,1),
        TopicName            nvarchar(30)  NOT NULL ,
        Description          varchar(60)  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL ,
		CONSTRAINT PKTopic PRIMARY KEY NONCLUSTERED HASH (TopicId) WITH (BUCKET_COUNT=10000)
)WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA);
GO

--PRIMARY KEY's placed inline with table, as each table needs a primary key

--ALTER TABLE Attendees.AttendeeType
--     ADD CONSTRAINT PKAttendeeType PRIMARY KEY CLUSTERED (AttendeeType);

--ALTER TABLE Attendees.MessagingUser
--     ADD CONSTRAINT PKMessagingUser PRIMARY KEY CLUSTERED (MessagingUserId);

--ALTER TABLE Attendees.UserConnection
--     ADD CONSTRAINT PKUserConnection PRIMARY KEY CLUSTERED (UserConnectionId);
     
--ALTER TABLE Messages.Message
--     ADD CONSTRAINT PKMessage PRIMARY KEY CLUSTERED (MessageId);

--ALTER TABLE Messages.MessageTopic
--     ADD CONSTRAINT PKMessageTopic PRIMARY KEY CLUSTERED (MessageTopicId);

--ALTER TABLE Messages.Topic
--     ADD CONSTRAINT PKTopic PRIMARY KEY CLUSTERED (TopicId);
GO


ALTER TABLE Messages.Message
     ADD CONSTRAINT AKMessage_TimeUserAndText UNIQUE
      (RoundedMessageTime, MessagingUserId, Text);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT AKTopic_Name UNIQUE (TopicName);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT AKMessageTopic_TopicAndMessage UNIQUE
      (MessageId, TopicId, UserDefinedTopicName);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AKMessagingUser_UserHandle UNIQUE HASH (UserHandle) WITH (BUCKET_COUNT=10000);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT AKMessagingUser_AttendeeNumber UNIQUE HASH 
     (AttendeeNumber) WITH (BUCKET_COUNT=10000);
     
ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT AKUserConnection_Users UNIQUE HASH
     (MessagingUserId, ConnectedToMessagingUserId) WITH (BUCKET_COUNT=10000);
GO
SELECT CONCAT(OBJECT_SCHEMA_NAME(object_id),'.',
              OBJECT_NAME(object_id)) as object_name,
              name,is_primary_key, is_unique_constraint
FROM   sys.indexes
WHERE  OBJECT_SCHEMA_NAME(object_id) <> 'sys'
  AND  is_primary_key = 1 or is_unique_constraint = 1
ORDER BY object_name, is_primary_key DESC, name
GO

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

ALTER TABLE Attendees.MessagingUser
       ADD CONSTRAINT FKMessagingUser$IsSent$Messages_Message
            FOREIGN KEY (AttendeeType) REFERENCES Attendees.AttendeeType(AttendeeType)
            --ON UPDATE CASCADE
            ON DELETE NO ACTION;
GO

--no cascade anyhow, so this example doesn't make sense anymore.
--ALTER TABLE Attendees.UserConnection
--        ADD CONSTRAINT 
--          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection 
--        FOREIGN KEY (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
--        ON UPDATE NO ACTION
--        ON DELETE CASCADE;

--ALTER TABLE Attendees.UserConnection
--        ADD CONSTRAINT 
--          FKMessagingUser$IsConnectedToUserVia$Attendees_UserConnection 
--        FOREIGN KEY  (ConnectedToMessagingUserId) 
--                              REFERENCES Attendees.MessagingUser(MessagingUserId)
--        ON UPDATE NO ACTION
--        ON DELETE CASCADE;
--GO
--PRINT 'you should have received an error from the second ALTER TABLE'
--GO

--ALTER TABLE Attendees.UserConnection
--        DROP CONSTRAINT 
--          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection;
--GO

ALTER TABLE Attendees.UserConnection
        ADD CONSTRAINT 
          FKMessagingUser$ConnectsToUserVia$Attendees_UserConnection 
        FOREIGN KEY (MessagingUserId) REFERENCES Attendees.MessagingUser(MessagingUserId)
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

ALTER TABLE Messages.Topic
   ADD CONSTRAINT CHKTopic_Name_NotEmpty
       CHECK (LEN(RTRIM(TopicName)) > 0);

ALTER TABLE Messages.MessageTopic
   ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NotEmpty
       CHECK (LEN(RTRIM(UserDefinedTopicName)) > 0);
GO





/*
ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
     CHECK (LEN(Rtrim(UserHandle)) >= 5 
             AND LTRIM(UserHandle) LIKE '[a-z]' +
                            Tools.String$Replicate('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));
--GO
--Msg 10794, Level 16, State 95, Line 282
--The function 'replicate' is not supported with memory optimized tables.
--Msg 10794, Level 16, State 95, Line 282
--The function 'like' is not supported with memory optimized tables.
*/
--build rather complex looking function. Didn't put in tools because this is a tool that you
--would only want to use for MemoryOptimized issues
CREATE SCHEMA MemOptTools;
GO
CREATE OR ALTER FUNCTION MemOptTools.String$CheckSimpleAlphaNumeric
(
    @inputString nvarchar(MAX)
)
RETURNS bit
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH(TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'English')
    DECLARE @i int = 1, @output bit = 1;

    WHILE @i <= LEN(@inputString)
    BEGIN
	    --ascii function not available. if you need something other than simple alphanumeric, would need to get 
		--more "interesting" to make it happen
        IF NOT(SUBSTRING(@inputString, @i, 1) IN ( '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C',
                                                   'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                                                   'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c',
                                                   'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p',
                                                   'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' ))
            SET @output = 0;

        SET @i = @i + 1;
    END;

    RETURN @output;
END;
GO

ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
		CHECK (LEN(Rtrim(UserHandle)) >= 5 
		      AND MemOptTools.String$CheckSimpleAlphaNumeric(TRIM(UserHandle)) = 1)
GO

--identity insert instead of sequence, for the user defined topic
set identity_insert Messages.Topic ON
INSERT INTO Messages.Topic(TopicId, TopicName, Description)
VALUES (0,'User Defined','User Enters Their Own User Defined Topic');
set identity_insert Messages.Topic OFF
GO

ALTER TABLE Messages.MessageTopic
  ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NullUnlessUserDefined
   CHECK ((UserDefinedTopicName is NULL and TopicId <> 0)
              or (TopicId = 0 and UserDefinedTopicName is NOT NULL));
GO

------------------------
--Triggers
------------------------
-- SQL Server Syntax
-- Trigger on an INSERT, UPDATE, or DELETE statement to a 
-- table (DML Trigger on memory-optimized tables)
GO
CREATE SCHEMA Base;
GO
CREATE TYPE Base.Surrogate AS TABLE(
  SurrogateId int,

  INDEX TT_SurrogateId HASH (SurrogateId) WITH ( BUCKET_COUNT = 32)
)
WITH ( MEMORY_OPTIMIZED = ON );
GO

--Triggers need to be updated to use row at a time processing
CREATE TRIGGER Messages.MessageTopic$AfterInsertTrigger
ON Messages.MessageTopic
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]
          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT MessageTopicId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.MessageTopic 
		        SET    RowCreateTime = DEFAULT,
				       RowLastUpdateTime = DEFAULT
				WHERE  MessageTopicId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO

--Triggers need to be updated to use row at a time processing
CREATE TRIGGER Messages.MessageTopic$AfterUpdateTrigger
ON Messages.MessageTopic
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]
          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate,
				  @PreviousRowCreateTime datetime2(0);

		  INSERT INTO @SurrogateKey
		  SELECT MessageTopicId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				SELECT @PreviousRowCreateTime = RowCreateTime
				FROM   deleted
				WHERE  MessageTopicId = @SurrogateId

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.MessageTopic 
		        SET    RowCreateTime = @PreviousRowCreateTime, --Make sure no change will be saved.
				       RowLastUpdateTime = DEFAULT
				WHERE  MessageTopicId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO




--Triggers need to be updated to use row at a time processing
CREATE TRIGGER Message$AfterInsertTrigger
ON Messages.Message
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]
          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT MessageId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.Message 
		        SET    RowCreateTime = DEFAULT,
				       RowLastUpdateTime = DEFAULT
				WHERE  MessageId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO

--Triggers need to be updated to use row at a time processing
CREATE TRIGGER Message$AfterUpdateTrigger
ON Messages.Message
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]
          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT MessageId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.Message 
		        SET    RowCreateTime = RowCreateTime,
				       RowLastUpdateTime = DEFAULT
				WHERE  MessageId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO



--Triggers need to be updated to use row at a time processing
CREATE TRIGGER MessagingUser$AfterInsertTrigger
ON Attendees.MessagingUser
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

		  --todo:
		 	--ALTER TABLE Attendees.MessagingUser 
			--  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
			--     CHECK  LTRIM(UserHandle) LIKE '[a-z]' +
			--                            REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));


          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT MessagingUserId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Attendees.MessagingUser 
		        SET    RowCreateTime = DEFAULT,
				       RowLastUpdateTime = DEFAULT
				WHERE  MessagingUserId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO

--Triggers need to be updated to use row at a time processing
CREATE TRIGGER MessagingUser$AfterUpdateTrigger
ON Attendees.MessagingUser
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

		  --todo:
		 	--ALTER TABLE Attendees.MessagingUser 
			--  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
			--     CHECK  LTRIM(UserHandle) LIKE '[a-z]' +
			--                            REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));


          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT MessagingUserId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Attendees.MessagingUser 
		        SET    RowCreateTime = RowCreateTime,
				       RowLastUpdateTime = DEFAULT
				WHERE  MessagingUserId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO




--Triggers need to be updated to use row at a time processing
CREATE TRIGGER UserConnection$AfterInsertTrigger
ON Attendees.UserConnection
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT UserConnectionId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Attendees.UserConnection 
		        SET    RowCreateTime = DEFAULT,
				       RowLastUpdateTime = DEFAULT
				WHERE  UserConnectionId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO


--Triggers need to be updated to use row at a time processing
CREATE TRIGGER UserConnection$AfterUpdateTrigger
ON Attendees.UserConnection
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT UserConnectionId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Attendees.UserConnection 
		        SET    RowCreateTime = RowCreateTime,
				       RowLastUpdateTime = DEFAULT
				WHERE  UserConnectionId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO

  --Triggers need to be updated to use row at a time processing
CREATE TRIGGER Topic$AfterInsertTrigger
ON Messages.Topic
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER INSERT AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT TopicId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.Topic 
		        SET    RowCreateTime = DEFAULT,
				       RowLastUpdateTime = DEFAULT
				WHERE  TopicId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH;
END;
GO

 --Triggers need to be updated to use row at a time processing
CREATE TRIGGER Topic$AfterUpdateTrigger
ON Messages.Topic
WITH NATIVE_COMPILATION, SCHEMABINDING
AFTER UPDATE AS
BEGIN ATOMIC WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
		  
		  --[validation section]

          --[modification section]

		  --update the RowTimes
		  DECLARE @SurrogateId int,
		          @ContinueLoop bit = 1,
                  @SurrogateKey Base.Surrogate;

		  INSERT INTO @SurrogateKey
		  SELECT TopicId
		  FROM   INSERTED;

          WHILE (@ContinueLoop=1) -- There will always be a row if you reach here
		    BEGIN
			    SELECT TOP(1) @SurrogateId = SurrogateId
				FROM   @SurrogateKey;

				IF @@RowCount = 0 SET @ContinueLoop = 0;

				DELETE FROM @SurrogateKey 
				WHERE SurrogateId = @SurrogateId;

				UPDATE Messages.Topic 
		        SET    RowCreateTime = RowCreateTime,
				       RowLastUpdateTime = DEFAULT
				WHERE  TopicId = @SurrogateId;
			END

   END TRY
   BEGIN CATCH
      THROW; --will halt the batch or be caught by the caller's catch block
  END CATCH
END
GO



----------------------------------
-- Extended Properties
----------------------------------

--Messages schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Messaging objects for In-Memory Version',
   @level0type = 'Schema', @level0name = 'Messages';

----Messages.Topic table
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = ' Pre-defined topics for messages',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic';

----Messages.Topic.TopicId 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing a Topic',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic',
--   @level2type = 'Column', @level2name = 'TopicId';

----Messages.Topic.Name
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'The name of the topic',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic',
--   @level2type = 'Column', @level2name = 'Name';

----Messages.Topic.Description
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Description of the purpose and utilization of the topics',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic',
--   @level2type = 'Column', @level2name = 'Description';

----Messages.Topic.RowCreateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was created',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic',
--   @level2type = 'Column', @level2name = 'RowCreateTime';

----Messages.Topic.RowLastUpdateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was last updated',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Topic',
--   @level2type = 'Column', @level2name = 'RowLastUpdateTime';

--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'User Id of the user that is being sent a message',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name = 'SentToMessagingUserId';
   
----Messages.Message.MessagingUserId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value ='User Id of the user that sent the message',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name =  'MessagingUserId';

----Messages.Message.Text 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Text of the message being sent',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name = 'Text';

----Messages.Message.MessageTime 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'The time the message is sent, at a grain of one second',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name = 'MessageTime';
 
-- --Messages.Message.RowCreateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was created',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name = 'RowCreateTime';

----Messages.Message.RowLastUpdateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was last updated',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'Message',
--   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
   

----Messages.Message table
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Relates a message to a topic',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic';

----Messages.Message.MessageTopicId 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing a MessageTopic',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'MessageTopicId';
   
--   --Messages.Message.MessageId 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing the message that is being associated with a topic',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'MessageId';

----Messages.MessageUserDefinedTopicName 
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Allows the user to choose the “UserDefined” topic style and set their own topic ',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'UserDefinedTopicName';

--   --Messages.Message.TopicId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing the topic that is being associated with a message',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'TopicId';

-- --Messages.MessageTopic.RowCreateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was created',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'RowCreateTime';

----Messages.MessageTopic.RowLastUpdateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was last updated',
--   @level0type = 'Schema', @level0name = 'Messages',
--   @level1type = 'Table', @level1name = 'MessageTopic',
--   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
--GO

--Attendees schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Attendee objects',
   @level0type = 'Schema', @level0name = 'Attendees';

----Attendees.AttendeeType table
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Domain of the different types of attendees that are supported',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'AttendeeType';

----Attendees.AttendeeType.AttendeeType
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Code representing a type of Attendee',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'AttendeeType',
--   @level2type = 'Column', @level2name = 'AttendeeType';

----Attendees.AttendeeType.AttendeeType
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Brief description explaining the Attendee Type',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'AttendeeType',
--   @level2type = 'Column', @level2name = 'Description';


----Attendees.MessagingUser table
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Represent a user of the messaging system, preloaded from another system with attendee information',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser';

----Attendees.MessagingUser.MessagingUserId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing a messaginguser',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'MessagingUserId';

----Attendees.MessagingUser.UserHandle
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'The name the user wants to be known as. Initially pre-loaded with a value based on the persons first and last name, plus a integer value, changeable by the user',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'UserHandle';

----Attendees.MessagingUser.AccessKeyValue
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'A password-like value given to the user on their badge to gain access',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'AccessKeyValue';

----Attendees.MessagingUser.AttendeeNumber
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'The number that the attendee is given to identify themselves, printed on front of badge',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'AttendeeNumber';

----Attendees.MessagingUser.FirstName
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Name of the user printed on badge for people to see',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'FirstName';

----Attendees.MessagingUser.LastName
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Name of the user printed on badge for people to see',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'LastName';

----Attendees.MessagingUser.AttendeeType
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Used to give the user special priviledges, such as access to speaker materials, vendor areas, etc.',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'AttendeeType';

----Attendees.MessagingUser.DisabledFlag
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Indicates whether or not the user'' account has been disabled',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'DisabledFlag';

----Attendees.MessagingUser.RowCreateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was created',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'RowCreateTime';

----Attendees.MessagingUser.RowLastUpdateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was last updated',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'MessagingUser',
--   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
--GO

----Attendees.UserConnection table
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Represents the connection of one user to another in order to filter results to a given set of users.',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection';

----Attendees.MessagingUser.UserConnectionId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Surrogate key representing a messaginguser',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection',
--   @level2type = 'Column', @level2name = 'UserConnectionId';

----Attendees.MessagingUser.UserConnectionId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'MessagingUserId of user that is going to connect themselves to another users ',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection',
--   @level2type = 'Column', @level2name = 'MessagingUserId';

----Attendees.MessagingUser.UserConnectionId
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'MessagingUserId of user that is being connected to',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection',
--   @level2type = 'Column', @level2name = 'ConnectedToMessagingUserId';

----Attendees.MessagingUser.RowCreateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was created',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection',
--   @level2type = 'Column', @level2name = 'RowCreateTime';

----Attendees.MessagingUser.RowLastUpdateTime
--EXEC sp_addextendedproperty @name = 'Description',
--   @value = 'Time when the row was last updated',
--   @level0type = 'Schema', @level0name = 'Attendees',
--   @level1type = 'Table', @level1name = 'UserConnection',
--   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
--GO
SELECT SCHEMA_NAME(major_id), Value
FROM   sys.extended_properties
WHERE  class_desc = 'SCHEMA'
  AND  SCHEMA_NAME(major_id) in ('Messages','Attendees')
GO	
SELECT SCHEMA_NAME, SCHEMA_OWNER
FROM   INFORMATION_SCHEMA.SCHEMATA
WHERE  SCHEMA_NAME <> SCHEMA_OWNER
GO

SELECT table_schema + '.' + TABLE_NAME as TABLE_NAME, COLUMN_NAME, 
             --types that have a character or binary lenght
        case when DATA_TYPE IN ('varchar','char','nvarchar','nchar','varbinary')
                      then DATA_TYPE + case when character_maximum_length = -1 then '(max)'
                                            else '(' + CAST(character_maximum_length as 
                                                                    varchar(4)) + ')' end
                 --types with a datetime precision
                 when DATA_TYPE IN ('time','datetime2','datetimeoffset')
                      then DATA_TYPE + '(' + CAST(DATETIME_PRECISION as varchar(4)) + ')'
                --types with a precision/scale
                 when DATA_TYPE IN ('numeric','decimal')
                      then DATA_TYPE + '(' + CAST(NUMERIC_PRECISION as varchar(4)) + ',' + 
                                            CAST(NUMERIC_SCALE as varchar(4)) +  ')'
                 --timestamp should be reported as rowversion
                 when DATA_TYPE = 'timestamp' then 'rowversion'
                 --and the rest. Note, float is declared with a bit length, but is
                 --represented as either float or real in types 
                 else DATA_TYPE end as DECLARED_DATA_TYPE,
        COLUMN_DEFAULT
FROM   INFORMATION_SCHEMA.COLUMNS
WHERE  TABLE_SCHEMA in ('Attendees','Messages')
ORDER BY TABLE_SCHEMA, TABLE_NAME,ORDINAL_POSITION;
GO
SELECT TABLE_SCHEMA, TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM   INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE  CONSTRAINT_SCHEMA in ('Attendees','Messages')
ORDER  BY  CONSTRAINT_SCHEMA, TABLE_NAME;
GO
SELECT OBJECT_SCHEMA_NAME(parent_id) + '.' + OBJECT_NAME(parent_id) AS TABLE_NAME, 
           name AS TRIGGER_NAME, 
           CASE WHEN is_instead_of_trigger = 1 then 'INSTEAD OF' else 'AFTER' End 
                        as TRIGGER_FIRE_TYPE
FROM   sys.triggers
WHERE  type_desc = 'SQL_TRIGGER' --not a clr trigger
  AND  parent_class = 1 --DML Triggers
  AND OBJECT_SCHEMA_NAME(parent_id) IN ('Attendees','Messages')
ORDER BY TABLE_NAME, TRIGGER_NAME;
GO

SELECT  TABLE_SCHEMA + '.' + TABLE_NAME AS TABLE_NAME,
        TABLE_CONSTRAINTS.CONSTRAINT_NAME, CHECK_CLAUSE
FROM    INFORMATION_SCHEMA.TABLE_CONSTRAINTS
            JOIN INFORMATION_SCHEMA.CHECK_CONSTRAINTS
               ON TABLE_CONSTRAINTS.CONSTRAINT_SCHEMA = 
                                CHECK_CONSTRAINTS.CONSTRAINT_SCHEMA
                  AND TABLE_CONSTRAINTS.CONSTRAINT_NAME = CHECK_CONSTRAINTS.CONSTRAINT_NAME
WHERE TABLE_SCHEMA IN ('Attendees','Messages')
GO

select *
from   sys.tables
where  object_schema_Name(object_id) IN ('Attendees','Messages');

select *
from   sys.triggers
where  object_schema_Name(parent_id) IN ('Attendees','Messages');