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
CREATE OR ALTER FUNCTION MemOptTools.String$Replicate
(
    @inputString    nvarchar(1000),
    @replicateCount smallint
)
RETURNS nvarchar(1000)
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH(TRANSACTION ISOLATION LEVEL = SNAPSHOT, 
                  LANGUAGE = N'English')
    DECLARE @i int = 0, @output nvarchar(1000) = '';

    WHILE @i < @replicateCount
    BEGIN
        SET @output = @output + @inputString;
        SET @i = @i + 1;
    END;

    RETURN @output;
END;
GO