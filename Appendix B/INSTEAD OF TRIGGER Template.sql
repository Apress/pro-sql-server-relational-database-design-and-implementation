CREATE TRIGGER <schema>.<tablename>$InsteadOf<actions>Trigger
ON <schema>.<tablename>
INSTEAD OF <comma delimited actions> AS
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
    @rowsAffected = (SELECT COUNT(*) FROM inserted);
   --@rowsAffected = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   BEGIN TRY
          --[validation section]
          --[modification section]
          --<perform action>
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
