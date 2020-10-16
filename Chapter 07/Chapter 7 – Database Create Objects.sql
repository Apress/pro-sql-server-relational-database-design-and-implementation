/*
CREATE DATABASE ConferenceMessaging;
GO
*/

USE ConferenceMessaging
go


DROP TABLE IF EXISTS Attendees.UserConnection, Messages.MessageTopic,Messages.Topic,Messages.Message, Attendees.MessagingUser,Attendees.AttendeeType;
DROP SEQUENCE IF EXISTS Messages.TopicIdGenerator;
GO

DROP SCHEMA IF EXISTS Attendees;
DROP SCHEMA IF EXISTS Messages;
GO

CREATE SCHEMA Messages; --tables pertaining to the messages being sent
GO
CREATE SCHEMA Attendees; --tables pertaining to the attendees and how they can send messages
GO
ALTER AUTHORIZATION ON SCHEMA::Messages To DBO;
GO
ALTER AUTHORIZATION ON SCHEMA::Attendees To DBO;
GO

CREATE SEQUENCE Messages.TopicIdGenerator
AS INT    
MINVALUE 10000 --starting value
NO MAXVALUE --technically will max out at max int
START WITH 10000 --value where the sequence will start, differs from min based on 
             --cycle property
INCREMENT BY 1 --number that is added the previous value
NO CYCLE --if setting is cycle, when it reaches max value it starts over
CACHE 100; --Use adjust number of values that SQL Server caches. Cached values would
          --be lost if the server is restarted, but keeping them in RAM makes access faster;

GO
CREATE TABLE Attendees.AttendeeType ( 
        AttendeeType         varchar(20)  NOT NULL ,
        Description          varchar(60)  NOT NULL 
);
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
        RoundedMessageTime  as (dateadd(hour,datepart(hour,MessageTime),
                                       CAST(CAST(MessageTime as date)as datetime2(0)) ))
                                       PERSISTED  NOT NULL,
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
        TopicId int NOT NULL CONSTRAINT DFLTTopic_TopicId 
                                DEFAULT(NEXT VALUE FOR  Messages.TopicIdGenerator),
        TopicName            nvarchar(30)  NOT NULL ,
        Description          varchar(60)  NOT NULL ,
        RowCreateTime        datetime2(0)  NOT NULL ,
        RowLastUpdateTime    datetime2(0)  NOT NULL 
);
GO
ALTER TABLE Attendees.AttendeeType
     ADD CONSTRAINT PKAttendeeType PRIMARY KEY CLUSTERED (AttendeeType);

ALTER TABLE Attendees.MessagingUser
     ADD CONSTRAINT PKMessagingUser PRIMARY KEY CLUSTERED (MessagingUserId);

ALTER TABLE Attendees.UserConnection
     ADD CONSTRAINT PKUserConnection PRIMARY KEY CLUSTERED (UserConnectionId);
     
ALTER TABLE Messages.Message
     ADD CONSTRAINT PKMessage PRIMARY KEY CLUSTERED (MessageId);

ALTER TABLE Messages.MessageTopic
     ADD CONSTRAINT PKMessageTopic PRIMARY KEY CLUSTERED (MessageTopicId);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT PKTopic PRIMARY KEY CLUSTERED (TopicId);
GO

ALTER TABLE Messages.Message
     ADD CONSTRAINT AKMessage_TimeUserAndText UNIQUE
      (RoundedMessageTime, MessagingUserId, Text);

ALTER TABLE Messages.Topic
     ADD CONSTRAINT AKTopic_TopicName UNIQUE (TopicName);

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



ALTER TABLE Attendees.MessagingUser
   ADD CONSTRAINT DFLTMessagingUser_DisabledFlag
   DEFAULT (0) FOR DisabledFlag;
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
            ON UPDATE CASCADE
            ON DELETE NO ACTION;
GO


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

CREATE TRIGGER MessagingUser$InsteadOfDeleteTrigger
ON Attendees.MessagingUser
INSTEAD OF DELETE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
   --@     rowsAffected int = (select count(*) from inserted);
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
		  WHERE  ConnectedToMessagingUserId IN (SELECT MessagingUserId FROM DELETED);

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
   ADD CONSTRAINT CHKTopic_TopicName_NotEmpty
       CHECK (LEN(RTRIM(TopicName)) > 0);

ALTER TABLE Messages.MessageTopic
   ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NotEmpty
       CHECK (LEN(RTRIM(UserDefinedTopicName)) > 0);
GO

ALTER TABLE Attendees.MessagingUser 
  ADD CONSTRAINT CHKMessagingUser_UserHandle_LengthAndStart
     CHECK (LEN(Rtrim(UserHandle)) >= 5 
             AND LTRIM(UserHandle) LIKE '[a-z]' +
                            REPLICATE('[a-z1-9]',LEN(RTRIM(UserHandle)) -1));
GO


INSERT INTO Messages.Topic(TopicId, TopicName, Description)
VALUES (0,'User Defined','User Enters Their Own User Defined Topic');

GO

ALTER TABLE Messages.MessageTopic
  ADD CONSTRAINT CHKMessageTopic_UserDefinedTopicName_NullUnlessUserDefined
   CHECK ((UserDefinedTopicName is NULL and TopicId <> 0)
              or (TopicId = 0 and UserDefinedTopicName is NOT NULL));
GO

------------------------
--Triggers
------------------------


CREATE TRIGGER MessageTopic$InsteadOfInsertTrigger
ON Messages.MessageTopic
INSTEAD OF INSERT AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
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
          INSERT INTO Messages.MessageTopic (MessageId, UserDefinedTopicName,
                                            TopicId,RowCreateTime,RowLastUpdateTime)
          SELECT MessageId, UserDefinedTopicName, TopicId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO


CREATE TRIGGER Messages.MessageTopic$InsteadOfUpdateTrigger
ON Messages.MessageTopic
INSTEAD OF UPDATE AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

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
                RowCreateTime = MessageTopic.RowCreateTime, --no changes allowed
                RowLastUpdateTime = SYSDATETIME()
          FROM  inserted 
                   JOIN Messages.MessageTopic 
                        on inserted.MessageTopicId = MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION;

      THROW; --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO


CREATE TRIGGER Messages.Topic$InsteadOfInsertTrigger
ON Messages.Topic
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
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
          INSERT INTO Messages.Topic (TopicId, TopicName, Description,
										RowCreateTime,RowLastUpdateTime)
          SELECT TopicId, TopicName, Description,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;
     END CATCH
END
GO
CREATE TRIGGER Topic$InsteadOfUpdateTrigger
ON Messages.Topic
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Topic 
		  SET TopicName = Inserted.TopicName,
			  Description = Inserted.Description,
		      RowCreateTime = Topic.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Topic 
				on inserted.TopicId = Topic.TopicId;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;
			 
		THROW;

     END CATCH
END
GO

CREATE TRIGGER Message$InsteadOfInsertTrigger
ON Messages.Message
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
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
          INSERT INTO Messages.Message (SentToMessagingUserId, 
		                                MessagingUserId,Text, MessageTime, 
										RowCreateTime,RowLastUpdateTime)
          SELECT  SentToMessagingUserId, 
		          MessagingUserId,Text, MessageTime,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO
CREATE TRIGGER Message$InsteadOfUpdateTrigger
ON Messages.Message
INSTEAD OF UPDATE AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE Message 
		  SET SentToMessagingUserId  = Inserted.SentToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
			  Text = Inserted.Text,
			  MessageTime = Inserted.MessageTime, 
		      RowCreateTime = Message.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Messages.Message 
				on inserted.MessageId = Message.MessageId
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO


CREATE TRIGGER MessagingUser$InsteadOfInsertTrigger
ON Attendees.MessagingUser
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
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
          INSERT INTO Attendees.MessagingUser (UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,
										RowCreateTime,RowLastUpdateTime)
          SELECT UserHandle, AccessKeyValue, AttendeeNumber, FirstName, LastName,
		                                AttendeeType, DisabledFlag,SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
              IF @@trancount > 0
                  ROLLBACK TRANSACTION;

			  THROW;

     END CATCH
END
GO


CREATE TRIGGER MessageTopic$UpdateRowControlsTrigger
ON Messages.MessageTopic
AFTER UPDATE AS
BEGIN

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          UPDATE MessageTopic 
          SET    RowCreateTime = SYSDATETIME(),
                 RowLastUpdateTime = SYSDATETIME()
          FROM   inserted 
                    JOIN Messages.MessageTopic 
                        on inserted.MessageTopicId = MessageTopic.MessageTopicId;
   END TRY
   BEGIN CATCH
      IF @@trancount > 0
          ROLLBACK TRANSACTION

      THROW --will halt the batch or be caught by the caller's catch block

  END CATCH
END
GO

CREATE TRIGGER UserConnection$InsteadOfInsertTrigger
ON Attendees.UserConnection
INSTEAD OF INSERT AS
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
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
          INSERT INTO Attendees.UserConnection (ConnectedToMessagingUserId, MessagingUserId, 
										RowCreateTime,RowLastUpdateTime)
          SELECT ConnectedToMessagingUserId, MessagingUserId, SYSDATETIME(), SYSDATETIME()
          FROM   inserted ;
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO

CREATE TRIGGER UserConnection$InsteadOfUpdateTrigger
ON Attendees.UserConnection
INSTEAD OF UPDATE AS
BEGIN

    DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for update or delete trigger
   --count instead of @@rowcount due to merge behavior that sets @@rowcount to a number
   --that is equal to number of merged rows, not rows being checked in trigger
           @rowsAffected int = (select count(*) from inserted)
   --@rowsAffected = (select count(*) from deleted)

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 return;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
		  UPDATE UserConnection 
		  SET ConnectedToMessagingUserId = Inserted.ConnectedToMessagingUserId,
			  MessagingUserId = Inserted.MessagingUserId,
		      RowCreateTime = UserConnection.RowCreateTime, --no changes allowed
		      RowLastUpdateTime = SYSDATETIME()
		  FROM   inserted 
		            join Attendees.UserConnection 
				on inserted.UserConnectionId = UserConnection.UserConnectionId
   END TRY
   BEGIN CATCH
        IF @@trancount > 0
            ROLLBACK TRANSACTION;

		THROW;
   END CATCH
END
GO
 
----------------------------------
-- Extended Properties
----------------------------------

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

EXEC sp_addextendedproperty @name = 'Description',
   @value = 'User Id of the user that is being sent a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'SentToMessagingUserId';
   
--Messages.Message.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value ='User Id of the user that sent the message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name =  'MessagingUserId';

--Messages.Message.Text 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Text of the message being sent',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'Text';

--Messages.Message.MessageTime 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The time the message is sent, at a grain of one second',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'MessageTime';
 
 --Messages.Message.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.Message.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'Message',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
   

--Messages.Message table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Relates a message to a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic';

--Messages.Message.MessageTopicId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a MessageTopic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageTopicId';
   
   --Messages.Message.MessageId 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the message that is being associated with a topic',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'MessageId';

--Messages.MessageUserDefinedTopicName 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Allows the user to choose the “UserDefined” topic style and set their own topic ',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'UserDefinedTopicName';

   --Messages.Message.TopicId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing the topic that is being associated with a message',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'TopicId';

 --Messages.MessageTopic.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Messages.MessageTopic.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Messages',
   @level1type = 'Table', @level1name = 'MessageTopic',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees schema 
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Attendee objects',
   @level0type = 'Schema', @level0name = 'Attendees';

--Attendees.AttendeeType table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Domain of the different types of attendees that are supported',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Code representing a type of Attendee',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.AttendeeType.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Brief description explaining the Attendee Type',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'AttendeeType',
   @level2type = 'Column', @level2name = 'Description';


--Attendees.MessagingUser table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represent a user of the messaging system, preloaded from another system with attendee information',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser';

--Attendees.MessagingUser.MessagingUserId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserHandle
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The name the user wants to be known as. Initially pre-loaded with a value based on the persons first and last name, plus a integer value, changeable by the user',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'UserHandle';

--Attendees.MessagingUser.AccessKeyValue
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'A password-like value given to the user on their badge to gain access',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AccessKeyValue';

--Attendees.MessagingUser.AttendeeNumber
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'The number that the attendee is given to identify themselves, printed on front of badge',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeNumber';

--Attendees.MessagingUser.FirstName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'FirstName';

--Attendees.MessagingUser.LastName
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Name of the user printed on badge for people to see',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'LastName';

--Attendees.MessagingUser.AttendeeType
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Used to give the user special priviledges, such as access to speaker materials, vendor areas, etc.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'AttendeeType';

--Attendees.MessagingUser.DisabledFlag
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Indicates whether or not the user'' account has been disabled',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'DisabledFlag';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'MessagingUser',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO

--Attendees.UserConnection table
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Represents the connection of one user to another in order to filter results to a given set of users.',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Surrogate key representing a messaginguser',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'UserConnectionId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is going to connect themselves to another users ',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'MessagingUserId';

--Attendees.MessagingUser.UserConnectionId
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'MessagingUserId of user that is being connected to',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'ConnectedToMessagingUserId';

--Attendees.MessagingUser.RowCreateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was created',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowCreateTime';

--Attendees.MessagingUser.RowLastUpdateTime
EXEC sp_addextendedproperty @name = 'Description',
   @value = 'Time when the row was last updated',
   @level0type = 'Schema', @level0name = 'Attendees',
   @level1type = 'Table', @level1name = 'UserConnection',
   @level2type = 'Column', @level2name = 'RowLastUpdateTime';
GO
