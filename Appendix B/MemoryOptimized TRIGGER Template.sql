CREATE TRIGGER <schema>.<tablename>$<actions>[<purpose>]Trigger
ON <schema>.<tablename>
WITH NATIVE_COMPILATION, SCHEMABINDING
<AFTER or INSTEAD OF> <comma delimited actions> AS
BEGIN ATOMIC WITH 
    (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

   --use inserted for insert or update trigger, deleted for update 
   --or delete trigger count instead of @@ROWCOUNT due to merge behavior 
   --that sets @@ROWCOUNT to a number that is equal to number of merged 
   --rows, not rows being checked in trigger
   DECLARE @msg varchar(2000),    --used to hold the error message

   --Natively compiled objects can't be the target of a MERGE currently, 
   --so could use @@ROWCOUNT, but this is safer for the future
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
   --           @rowsAffected int = (SELECT COUNT(*) FROM deleted);
       
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;
   BEGIN TRY
          --[validation section]
          --[modification section]
          --[perform action] --INSTEAD OF ONLY
   END TRY
   BEGIN CATCH
        --will halt the batch or be caught by the caller's catch block
        THROW; 

   END CATCH;
END;
