IF SCHEMA_ID('Utility') IS NULL
	EXECUTE ('CREATE SCHEMA Utility;');
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