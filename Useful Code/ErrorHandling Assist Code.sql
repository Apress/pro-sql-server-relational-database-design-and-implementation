IF SCHEMA_ID('ErrorHandling') IS NULL
	EXECUTE ('CREATE SCHEMA ErrorHandling;')
GO
IF OBJECT_ID('ErrorHandling.ErrorLog','U') IS NULL 
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

CREATE OR ALTER PROCEDURE ErrorHandling.ErrorLog$Insert
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
