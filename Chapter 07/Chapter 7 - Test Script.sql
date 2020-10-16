SET NOCOUNT ON;
USE ConferenceMessaging;

--note, this script works for the MemoryOptimized version as well
--USE ConferenceMessagingMemoryOptimized
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
	VALUES ('SamJn','0000000000','00000000','Sam',
                                      'Johnson','Regular',0);
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
                                      'Johnson','Regular',0);
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
                'Wilma','Johnson','Regular',0);
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
          WHERE UserHandle = 'SamJn')
        ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
          WHERE UserHandle = 'WilmaJ')
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
          WHERE UserHandle = 'SamJn')
          ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'WilmaJ')  --
           ,'It looks like I will be late tonight',SYSDATETIME()),

          --Row2
          ((SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'SamJn')
           ,(SELECT MessagingUserId FROM Attendees.MessagingUser 
            WHERE UserHandle = 'WilmaJ')  --
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
                           WHERE UserHandle = 'SamJn'),
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


GO

DECLARE @TestName nvarchar(100) = 'UserHandle characters allowed didn''t work';
BEGIN TRY --Check UserHandle Check Constraint
	INSERT INTO [Attendees].[MessagingUser]
			   ([UserHandle],[AccessKeyValue],[AttendeeNumber]
			   ,[FirstName],[LastName],[AttendeeType]
			   ,[DisabledFlag])
	VALUES ('Wilma@','0000000000','00000001','Wilma','Johnson','Regular',0);
	THROW 50000,'No error raised',16;
End TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                          '; ErrorNumber:',ERROR_NUMBER(),
                          ' ErrorMessage:',ERROR_MESSAGE());
    IF ERROR_MESSAGE() NOT LIKE
             '%CHKMessagingUser_UserHandle_LengthAndStart%'
         THROW 50000,@msg,1;
END CATCH;
GO


DECLARE @TestName nvarchar(100) = 'UserHandle length check didn''t work';
BEGIN TRY --Check UserHandle Check Constraint
	INSERT INTO [Attendees].[MessagingUser]
			   ([UserHandle],[AccessKeyValue],[AttendeeNumber]
			   ,[FirstName],[LastName],[AttendeeType]
			   ,[DisabledFlag])
	VALUES ('WilF','0000000000','00000001','Wilma','Johnson','Regular',0);
	THROW 50000,'No error raised',16;
End TRY
BEGIN CATCH
       DECLARE @msg nvarchar(4000) = CONCAT(@Testname,       
                          '; ErrorNumber:',ERROR_NUMBER(),
                          ' ErrorMessage:',ERROR_MESSAGE());
    IF ERROR_MESSAGE() NOT LIKE
             '%CHKMessagingUser_UserHandle_LengthAndStart%'
         THROW 50000,@msg,1;
END CATCH;
GO

