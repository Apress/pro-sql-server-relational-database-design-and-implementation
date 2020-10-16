--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
EXIT


----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Database Security Prerequisites
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Connecting to a SQL Server Database
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Connecting to a Database Using a Login and a Database User
----------------------------------------------------------------------------------------------------------

/*
--square brackets required for WinAuth login because of the bracket
CREATE LOGIN [DomainName\drsql] FROM WINDOWS 
       WITH DEFAULT_DATABASE=tempdb, DEFAULT_LANGUAGE=us_english;
GO
*/


CREATE LOGIN Fred WITH PASSWORD=N'password' MUST_CHANGE, DEFAULT_DATABASE=tempdb,
     DEFAULT_LANGUAGE=us_english, CHECK_EXPIRATION=ON, CHECK_POLICY=ON;
GO

/*
ALTER SERVER ROLE sysadmin ADD MEMBER [Domain\drsql];
*/	 

CREATE SERVER ROLE SupportViewServer;
GO


GRANT  VIEW SERVER STATE to SupportViewServer; --run DMVs
GRANT  VIEW ANY DATABASE to SupportViewServer; --see any database
--set context to any database
GRANT  CONNECT ANY DATABASE to SupportViewServer; 
--see any data in databases
GRANT  SELECT ALL USER SECURABLES to SupportViewServer; 
GO

ALTER SERVER ROLE SupportViewServer ADD MEMBER Fred;
GO



CREATE DATABASE ClassicSecurityExample;
GO


CREATE LOGIN Barney WITH PASSWORD=N'Test', 
             DEFAULT_DATABASE=[tempdb], DEFAULT_LANGUAGE=[us_english], 
             CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;
GO

--On a connection where you have logged in as Barney:

--this will fail
USE ClassicSecurityExample;
GO

--on connection as sysadmin

USE ClassicSecurityExample;
GO
GRANT CONNECT TO guest;
GO

--On a connection where you have logged in as Barney:

--now allowed
USE ClassicSecurityExample;
GO

--on connection as sysadmin
REVOKE CONNECT TO guest;

--On a connection where are still logged in as Barney:

--still allowed, until you disconnect and reconnect. You should get error trying to connect to the database
USE ClassicSecurityExample;
GO
SELECT 'hi';


--on connection as sysadmin

--explicitly allow Barney access to the database
USE ClassicSecurityExample;
GO
CREATE USER BarneyUser FROM LOGIN Barney;
GO
GRANT CONNECT to BarneyUser;


--On a connection where logged in as Barney, and also as sysadmin:
USE ClassicSecurityExample;
GO
SELECT SUSER_SNAME() AS server_principal_name, 
       USER_NAME() AS database_principal_name;
GO

----------------------------------------------------------------------------------------------------------
--Using the Contained Database Model
----------------------------------------------------------------------------------------------------------

EXECUTE sp_configure 'contained database authentication', 1;
GO
RECONFIGURE WITH OVERRIDE;
GO

CREATE DATABASE ContainedDBSecurityExample CONTAINMENT = PARTIAL;
GO

-- set the contained database to be partial 
ALTER DATABASE ContainedDBSecurityExample SET CONTAINMENT = PARTIAL;
GO


USE ContainedDBSecurityExample;
GO
CREATE USER WilmaContainedUser WITH PASSWORD = 'p@sasdfaerord1';
GO

CREATE LOGIN Pebbles WITH PASSWORD = 'BamBam01$';
GO

CREATE USER PebblesUnContainedUser FROM LOGIN Pebbles;
GO

ALTER DATABASE ContainedDbSecurityExample  SET SINGLE_USER WITH ROLLBACK IMMEDIATE; 
GO
ALTER DATABASE ContainedDbSecurityExample  SET MULTI_USER; 
GO

ALTER DATABASE ContainedDbSecurityExample  SET CONTAINMENT = NONE;
GO

SELECT name
FROM   ContainedDBSecurityExample.sys.database_principals 
--3 part name since you are outside of db to make this change.                                                       
WHERE  authentication_type_desc = 'DATABASE';
GO

----------------------------------------------------------------------------------------------------------
--Impersonation
----------------------------------------------------------------------------------------------------------

USE master;
GO
CREATE DROP LOGIN SlateSystemAdmin 
   WITH PASSWORD = 'weqc33(*hjnNn3202x2x89*6(6';
GO

CREATE LOGIN Slate with PASSWORD = 'different-afal230920j8&^^3',
                                DEFAULT_DATABASE=tempdb;
GO

--Must execute in master Database
GRANT IMPERSONATE ON LOGIN::SlateSystemAdmin TO Slate;
GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Database Objects Securables
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Grantable Permissions
--*****
----------------------------------------------------------------------------------------------------------


SELECT  class_desc AS PermissionType, 
        OBJECT_SCHEMA_NAME(major_id) + '.' + OBJECT_NAME(major_id) 
                                                       AS ObjectName, 
        permission_name, state_desc, USER_NAME(grantee_principal_id) 
                                                                AS Grantee
FROM   sys.database_permissions;


----------------------------------------------------------------------------------------------------------
--Table Security
----------------------------------------------------------------------------------------------------------

USE ClassicSecurityExample;
GO
--start with a new schema for this test and create a 
--table for our demonstrations
CREATE SCHEMA TestPerms;
GO

CREATE TABLE TestPerms.TableExample
(
    TableExampleId int IDENTITY(1,1)
                   CONSTRAINT PKTableExample PRIMARY KEY,
    Value   varchar(10)
);
GO


CREATE USER Tony WITHOUT LOGIN;
GO


EXECUTE AS USER = 'Tony';

--causes error
INSERT INTO TestPerms.TableExample(Value)
VALUES ('a new row');
GO

REVERT; --return to admin user context
GRANT INSERT ON TestPerms.TableExample TO Tony;
GO


EXECUTE AS USER = 'Tony';

INSERT INTO TestPerms.TableExample(Value)
VALUES ('a new row');
GO


--causes error
SELECT TableExampleId, Value
FROM   TestPerms.TableExample;
GO


REVERT;
GRANT SELECT ON TestPerms.TableExample TO Tony;
GO

EXECUTE AS USER = 'Tony';

SELECT TableExampleId, Value
FROM   TestPerms.TableExample;

REVERT;

----------------------------------------------------------------------------------------------------------
--Column-Level Security
----------------------------------------------------------------------------------------------------------
CREATE USER Employee WITHOUT LOGIN;
CREATE USER Manager WITHOUT LOGIN;
GO


CREATE SCHEMA Products;
GO
CREATE TABLE Products.Product
(
    ProductId   int NOT NULL IDENTITY CONSTRAINT PKProduct PRIMARY KEY,
    ProductCode varchar(10) NOT NULL 
                               CONSTRAINT AKProduct_ProductCode UNIQUE,
    Description varchar(20) NOT NULL,
    UnitPrice   decimal(10,4) NOT NULL,
    ActualCost  decimal(10,4) NOT NULL
);
INSERT INTO Products.Product(ProductCode, Description, 
                             UnitPrice, ActualCost)
VALUES ('widget12','widget number 12',10.50,8.50),
       ('snurf98','snurfulator',99.99,2.50);
GO

GRANT SELECT on Products.Product to Employee,Manager;
DENY SELECT on Products.Product (ActualCost) to Employee;
GO


EXECUTE AS USER = 'Manager';
SELECT  *
FROM    Products.Product;
GO

REVERT;--revert back to SA level user or you will get an error that the
       --user cannot do this operation because the Manager user doesn't
       --have rights to impersonate the Employee
GO
EXECUTE AS USER = 'Employee';
GO
SELECT *
FROM   Products.Product;
GO


SELECT ProductId, ProductCode, Description, UnitPrice
FROM   Products.Product;
REVERT;

----------------------------------------------------------------------------------------------------------
--*****
--Roles
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--User-Defined Roles
----------------------------------------------------------------------------------------------------------
SELECT IS_MEMBER('HRManager');
GO

IF (SELECT IS_MEMBER('HRManager')) = 0 or (SELECT IS_MEMBER('HRManager')) IS NULL
       SELECT 'I..DON''T THINK SO!';

GO

CREATE USER Addi WITHOUT LOGIN;
CREATE USER Aria WITHOUT LOGIN;
CREATE USER Amanda WITHOUT LOGIN;
GO


CREATE ROLE HRWorkers;

ALTER ROLE HRWorkers ADD MEMBER Aria;
ALTER ROLE HRWorkers ADD MEMBER Amanda;
GO

CREATE SCHEMA Payroll;
GO
CREATE TABLE Payroll.EmployeeSalary
(
    EmployeeId  int NOT NULL CONSTRAINT PKEmployeeSalary PRIMARY KEY,
    SalaryAmount decimal(12,2) NOT NULL
);
GRANT SELECT ON Payroll.EmployeeSalary to HRWorkers;
GO

EXECUTE AS USER = 'Addi';

SELECT *
FROM   Payroll.EmployeeSalary;
GO

REVERT;
EXECUTE AS USER = 'Aria';

SELECT *
FROM   Payroll.EmployeeSalary;
GO


REVERT; --back to admin rights
DENY SELECT ON Payroll.EmployeeSalary TO Amanda;


EXECUTE AS USER = 'Amanda';
SELECT *
FROM   Payroll.EmployeeSalary;
GO

REVERT ;
EXECUTE AS USER = 'Aria';

--note, this query only returns rows for tables where the user has SOME rights
SELECT  TABLE_SCHEMA + '.' + TABLE_NAME AS tableName,
        HAS_PERMS_BY_NAME(TABLE_SCHEMA + '.' + TABLE_NAME, 
                         'OBJECT', 'SELECT') AS AllowSelect,
        HAS_PERMS_BY_NAME(TABLE_SCHEMA + '.' + TABLE_NAME, 
                         'OBJECT', 'INSERT') AS AllowInsert
FROM    INFORMATION_SCHEMA.TABLES;
REVERT ; --so you will be back to sysadmin rights for next code

----------------------------------------------------------------------------------------------------------
--Application Roles
----------------------------------------------------------------------------------------------------------
CREATE TABLE TestPerms.BobCan
(
    BobCanId int NOT NULL IDENTITY(1,1) CONSTRAINT PKBobCan PRIMARY KEY,
    Value varchar(10) NOT NULL
);
CREATE TABLE TestPerms.AppCan
(
    AppCanId int NOT NULL IDENTITY(1,1) CONSTRAINT PKAppCan PRIMARY KEY,
    Value varchar(10) NOT NULL
);
GO

CREATE USER Bob WITHOUT LOGIN;
GO


GRANT SELECT on TestPerms.BobCan to Bob;
GO

CREATE APPLICATION ROLE AppCan_application with password = '39292LjAsll2$3';
GO
GRANT SELECT on TestPerms.AppCan to AppCan_application;
GO

EXECUTE AS USER = 'Bob';
SELECT * FROM TestPerms.BobCan;
GO

SELECT * FROM TestPerms.AppCan;
GO

EXECUTE sp_setapprole 'AppCan_application', '39292LjAsll2$3';
GO
SELECT * FROM TestPerms.BobCan;
GO

SELECT * from TestPerms.AppCan;
GO

SELECT USER AS UserName;
GO

USE ClassicSecurityExample;
--Note that this must be executed as a single batch because of the variable
--for the cookie
DECLARE @cookie varbinary(8000);
EXECUTE sp_setapprole 'AppCan_application', '39292LjAsll2$3'
              , @fCreateCookie = true, @cookie = @cookie OUTPUT;

SELECT @cookie as cookie;
SELECT USER as beforeUnsetApprole;

EXEC sp_unsetapprole @cookie;

SELECT USER as afterUnsetApprole;

REVERT; --done with this user

----------------------------------------------------------------------------------------------------------
--*****
--Schemas
--*****
----------------------------------------------------------------------------------------------------------

USE WideWorldImporters; --or whatever name you have given it
GO
SELECT  SCHEMA_NAME(schema_id) AS schema_name, type_desc, COUNT(*)
FROM    sys.objects
WHERE   type_desc IN ('SQL_STORED_PROCEDURE','CLR_STORED_PROCEDURE',
                      'SQL_SCALAR_FUNCTION','CLR_SCALAR_FUNCTION',
                      'CLR_TABLE_VALUED_FUNCTION','SYNONYM',
                      'SQL_INLINE_TABLE_VALUED_FUNCTION',
                      'SQL_TABLE_VALUED_FUNCTION','USER_TABLE','VIEW')
GROUP BY  SCHEMA_NAME(schema_id), type_desc
ORDER BY schema_name;
GO
USE ClassicSecurityExample; 
GO

CREATE USER Tom WITHOUT LOGIN;
GRANT SELECT ON SCHEMA::TestPerms TO Tom;
GO

EXECUTE AS USER = 'Tom';
GO
SELECT * FROM TestPerms.AppCan;
GO
REVERT;
GO

CREATE TABLE TestPerms.SchemaGrant
(
    SchemaGrantId int CONSTRAINT PKSchemaGrant PRIMARY KEY
);
GO
EXECUTE AS USER = 'Tom';
GO
SELECT * FROM TestPerms.SchemaGrant;
GO
REVERT;

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Controlling Access to Data via T-SQL–Coded Objects
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA ProcTest;
GO
CREATE TABLE ProcTest.Misc
(
    GeneralValue varchar(20),
    SecretValue varchar(20)
);
GO
INSERT INTO ProcTest.Misc (GeneralValue, SecretValue)
VALUES ('somevalue','secret'),
       ('anothervalue','secret');
GO

CREATE PROCEDURE ProcTest.Misc$Select
AS
    SELECT GeneralValue
    FROM   ProcTest.Misc;
GO



CREATE USER ProcUser WITHOUT LOGIN;
GRANT EXECUTE on ProcTest.Misc$Select to ProcUser;
GO


EXECUTE AS USER = 'ProcUser';
GO
SELECT GeneralValue , SecretValue
FROM   ProcTest.Misc;
GO

EXECUTE ProcTest.Misc$Select;
GO


SELECT SCHEMA_NAME(schema_id) +'.' + name AS ProcedureName
FROM   sys.procedures;

REVERT;
GO


----------------------------------------------------------------------------------------------------------
--Impersonation WIthin Objects
----------------------------------------------------------------------------------------------------------

--
--Basic Impersonation Example
--

--this will be the owner of the primary schema
CREATE USER SchemaOwner WITHOUT LOGIN;
GRANT CREATE SCHEMA TO SchemaOwner;
GRANT CREATE TABLE TO SchemaOwner;

--this will be the procedure creator
CREATE USER ProcedureOwner WITHOUT LOGIN;
GRANT CREATE SCHEMA TO ProcedureOwner;
GRANT CREATE PROCEDURE TO ProcedureOwner;
GRANT CREATE TABLE TO ProcedureOwner;
GO

--this will be the average user who needs to access data
CREATE USER AveSchlub WITHOUT LOGIN;
GO


EXECUTE AS USER = 'SchemaOwner';
GO
CREATE SCHEMA SchemaOwnersSchema;
GO
CREATE TABLE SchemaOwnersSchema.Person
(
    PersonId    int NOT NULL CONSTRAINT PKPerson PRIMARY KEY,
    FirstName   varchar(20) NOT NULL,
    LastName    varchar(20) NOT NULL
);
GO
INSERT INTO SchemaOwnersSchema.Person
VALUES (1, 'Phil','Mutayblin'),
       (2, 'Del','Eets');
GO

GRANT SELECT ON SchemaOwnersSchema.Person TO ProcedureOwner;
GO

REVERT;--we can step back on the stack of principals, 
       --but we can't change directly to ProcedureOwner without giving 
       --ShemaOwner impersonation rights. Here I step back to the db_owner 
       --user you have used throughout the chapter
GO
EXECUTE AS USER = 'ProcedureOwner';
GO


CREATE SCHEMA ProcedureOwnerSchema;
GO
CREATE TABLE ProcedureOwnerSchema.OtherPerson
(
    PersonId    int NOT NULL CONSTRAINT PKOtherPerson PRIMARY KEY,
    FirstName   varchar(20) NOT NULL,
    LastName    varchar(20) NOT NULL
);
GO
INSERT INTO ProcedureOwnerSchema.OtherPerson
VALUES (1, 'DB','Smith');
INSERT INTO ProcedureOwnerSchema.OtherPerson
VALUES (2, 'Dee','Leater');
GO

REVERT;

SELECT tables.name AS TableName, schemas.name AS SchemaName,
       database_principals.name AS OwnerName
FROM   sys.tables
         JOIN sys.schemas
            ON tables.schema_id = schemas.schema_id
         JOIN sys.database_principals
            ON database_principals.principal_id = schemas.principal_id
WHERE  tables.name IN ('Person','OtherPerson');
GO

EXECUTE AS USER = 'ProcedureOwner';
GO

CREATE PROCEDURE ProcedureOwnerSchema.Person$asCaller
WITH EXECUTE AS CALLER --this is the default
AS
BEGIN
   SELECT  PersonId, FirstName, LastName
   FROM    ProcedureOwnerSchema.OtherPerson; --<-- ownership same as proc

   SELECT  PersonId, FirstName, LastName
   FROM    SchemaOwnersSchema.Person;  --<-- breaks ownership chain
END;
GO

CREATE PROCEDURE ProcedureOwnerSchema.Person$asSelf
WITH EXECUTE AS SELF --now this runs in context of procedureOwner,
                     --since it created it
AS
BEGIN
   SELECT  PersonId, FirstName, LastName
   FROM    ProcedureOwnerSchema.OtherPerson; --<-- ownership same as proc

   SELECT  PersonId, FirstName, LastName
   FROM    SchemaOwnersSchema.Person;  --<-- breaks ownership chain
END;
GO


GRANT EXECUTE ON ProcedureOwnerSchema.Person$asCaller TO AveSchlub;
GRANT EXECUTE ON ProcedureOwnerSchema.Person$asSelf TO AveSchlub;
GO

REVERT; EXECUTE AS USER = 'AveSchlub'; --If you receive error about not 
                        --being able to impersonate another user, it means 
                        --you are not executing as dbo..

--this proc is in context of the caller, in this case, AveSchlub
EXECUTE ProcedureOwnerSchema.Person$asCaller;
GO


--procedureOwner, so it works
EXECUTE ProcedureOwnerSchema.Person$asSelf;
GO

--
--Temporary Rights Elevation
--

REVERT;
GO
CREATE PROCEDURE dbo.TestCreateTableRights
AS
 BEGIN
    DROP TABLE IF EXISTS dbo.Test;
    CREATE TABLE dbo.Test
    (
        TestId int
    );
 END;
 GO

CREATE USER Leroy WITHOUT LOGIN;
GRANT EXECUTE on dbo.TestCreateTableRights to Leroy;
GO

EXECUTE AS USER = 'Leroy';
EXECUTE dbo.TestCreateTableRights;
GO

REVERT;
CREATE USER DboTableCreator WITHOUT LOGIN;
GRANT CREATE TABLE TO DboTableCreator; --lets user create a table at all
GRANT ALTER ON SCHEMA::dbo TO DboTableCreator; -- allows them to in dbo
GO

ALTER PROCEDURE dbo.TestCreateTableRights
WITH EXECUTE AS 'DboTableCreator'
AS
 BEGIN
    DROP TABLE IF EXISTS dbo.Test;
    CREATE TABLE dbo.Test
    (
        TestId int
    );
 END;
 GO

----------------------------------------------------------------------------------------------------------
--*****
--Views and Table-Valued Functions
--*****
----------------------------------------------------------------------------------------------------------

REVERT
GO

SELECT *
FROM   Products.Product;
GO

CREATE VIEW Products.AllProducts
AS
SELECT ProductId,ProductCode, Description, 
       UnitPrice, ActualCost, ProductType
FROM   Products.Product;
GO

CREATE VIEW Products.WarehouseProducts
AS
SELECT ProductId,ProductCode, Description
FROM   Products.Product;
GO

CREATE FUNCTION Products.ProductsLessThanPrice
(
    @UnitPrice  decimal(10,4)
)
RETURNS table
AS
     RETURN ( SELECT ProductId, ProductCode, Description, UnitPrice
              FROM   Products.Product
              WHERE  UnitPrice <= @UnitPrice);
GO

SELECT * FROM Products.ProductsLessThanPrice(20);

----------------------------------------------------------------------------------------------------------
--*****
--Row-Level Security
--*****
----------------------------------------------------------------------------------------------------------

/* in case you need to create these 
CREATE SCHEMA Products;
GO
CREATE TABLE Products.Product
(
    ProductId   int NOT NULL IDENTITY CONSTRAINT PKProduct PRIMARY KEY,
    ProductCode varchar(10) NOT NULL 
                                CONSTRAINT AKProduct_ProductCode UNIQUE,
    Description varchar(20) NOT NULL,
    UnitPrice   decimal(10,4) NOT NULL,
    ActualCost  decimal(10,4) NOT NULL
);
*/

ALTER TABLE Products.Product
   ADD ProductType varchar(20) NOT NULL 
                 CONSTRAINT DFLTProduct_ProductType DEFAULT ('not set');
GO
UPDATE Products.Product
SET    ProductType = 'widget'
WHERE  ProductCode = 'widget12';
GO
UPDATE Products.Product
SET    ProductType = 'snurf'
WHERE  ProductCode = 'snurf98';
GO

SELECT *
FROM  Products.Product
GO

----------------------------------------------------------------------------------------------------------
--*****
--Using Specific-Purpose Views to Provide Row-Level Security
--*****
----------------------------------------------------------------------------------------------------------

CREATE VIEW Products.WidgetProduct
AS
SELECT ProductId, ProductCode, Description, 
       UnitPrice, ActualCost, ProductType
FROM   Products.Product
WHERE  ProductType = 'widget'
WITH   CHECK OPTION; --This prevents the user from INSERTING/UPDATING 
                     --data that would not match the view's criteria
GO

CREATE USER Andrew WITHOUT LOGIN;
GO
GRANT SELECT ON Products.WidgetProduct TO Andrew;
GO

EXECUTE AS USER = 'Andrew';
SELECT *
FROM   Products.WidgetProduct;
GO

SELECT *
FROM   Products.Product;
GO
REVERT;
GO


CREATE VIEW Products.ProductSelective
AS
SELECT ProductId, ProductCode, Description, UnitPrice, ActualCost, ProductType
FROM   Products.Product
WHERE  ProductType <> 'snurf'
   or  (IS_MEMBER('snurfViewer') = 1)
   or  (IS_MEMBER('db_owner') = 1) --can't add db_owner to a role
WITH CHECK OPTION;
GO

--Granting to public for demo purposes only. Public role should be limited
--to only utility type objects that any user could use, much like there are
--system objects that are available to guest
GRANT SELECT ON Products.ProductSelective to public;
GO

CREATE ROLE SnurfViewer;
GO

EXECUTE AS USER = 'Andrew';
SELECT * FROM Products.ProductSelective;
REVERT;
GO

ALTER ROLE SnurfViewer ADD MEMBER Andrew;
GO

EXECUTE AS USER = 'Andrew';
SELECT * 
FROM Products.ProductSelective;

REVERT;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Using the Row-Level Security Feature
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA RowLevelSecurity;
GO

CREATE FUNCTION RowLevelSecurity.Products_Product$SecurityPredicate 
                                           (@ProductType AS varchar(20)) 
RETURNS TABLE 
WITH SCHEMABINDING --not required, but a good idea nevertheless
AS 
    RETURN (SELECT 1 AS Products_Product$SecurityPredicate  
            WHERE  @ProductType <> 'snurf'
                           OR (IS_MEMBER('snurfViewer') = 1)
                           OR (IS_MEMBER('db_owner') = 1));
GO

CREATE USER Valerie WITHOUT LOGIN;
GO
GRANT SELECT ON RowLevelSecurity.Products_Product$SecurityPredicate 
                                                              TO Valerie;
GO

EXECUTE AS USER = 'Valerie';
GO
SELECT 'snurf' AS ProductType,*
FROM   rowLevelSecurity.Products_Product$SecurityPredicate('snurf')
UNION ALL
SELECT 'widget' AS ProductType,*
FROM   rowLevelSecurity.Products_Product$SecurityPredicate('widget');

REVERT;
GO

REVOKE SELECT ON RowLevelSecurity.Products_Product$SecurityPredicate 
                                                              TO Valerie;
GO

CREATE SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy 
ADD FILTER PREDICATE rowLevelSecurity.Products_Product$SecurityPredicate
                                                        (ProductType) 
    ON Products.Product WITH (STATE = ON, SCHEMABINDING = ON); 
GO

CREATE SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy2
   ADD FILTER PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                                                             (ProductType) 
    ON Products.Product WITH (STATE = ON, SCHEMABINDING= ON); 
GO

GRANT SELECT, INSERT, UPDATE, DELETE ON Products.Product TO Valerie;
GO

EXECUTE AS USER = 'Valerie';

SELECT * 
FROM   Products.Product;

REVERT;
GO


EXECUTE AS USER = 'Valerie';

DELETE Products.Product
WHERE  ProductType = 'snurf';

REVERT;

--back as dbo user
SELECT *
FROM   Products.Product
WHERE  ProductType = 'snurf';
GO


EXECUTE AS USER = 'Valerie';

INSERT INTO Products.Product (ProductCode, Description, UnitPrice, ActualCost,ProductType)
VALUES  ('test' , 'Test' , 100 , 100  , 'snurf');

SELECT *
FROM   Products.Product
WHERE  ProductType = 'snurf';

REVERT;

SELECT *
FROM   Products.Product
WHERE  ProductType = 'snurf';
GO

--Note that you can alter a security policy, but it seems easier 
--to drop and recreate in most cases.
DROP SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy;

CREATE SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy
   ADD FILTER PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                                                              (ProductType) 
                                                      ON Products.Product,
   ADD BLOCK PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                                                              (ProductType) 
    ON Products.Product AFTER INSERT WITH (STATE = ON, SCHEMABINDING = ON); 
GO

EXECUTE AS USER = 'Valerie';

INSERT INTO Products.Product (ProductCode, Description, UnitPrice, 
                              ActualCost,ProductType)
VALUES  ('test2' , 'Test2' , 100 , 100  , 'snurf');

REVERT;
GO

DROP SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy;

CREATE SECURITY POLICY RowLevelSecurity.Products_Product_SecurityPolicy
    ADD BLOCK PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                      (ProductType) ON Products.Product AFTER INSERT,
    ADD BLOCK PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                      (ProductType) ON Products.Product BEFORE UPDATE,
    ADD BLOCK PREDICATE RowLevelSecurity.Products_Product$SecurityPredicate
                      (ProductType) ON Products.Product BEFORE DELETE
    WITH (STATE = ON, SCHEMABINDING = ON); 
GO

EXECUTE AS USER = 'Valerie';
GO

SELECT *
FROM   Products.Product;
GO

DELETE Products.Product
WHERE  ProductCode = 'Test';
GO

UPDATE Products.Product
SET    ProductType = 'snurf'
WHERE  ProductType = 'widget';

--But we cannot update the row back, even though we can see it:

UPDATE Products.Product
SET    ProductType = 'widget'
WHERE  ProductType = 'snurf';

REVERT;
GO

EXEC sys.sp_set_session_context @key = N'SecurityGroup', 
                                @value = 'Management';
GO

SELECT SESSION_CONTEXT(N'SecurityGroup');
GO

----------------------------------------------------------------------------------------------------------
--*****
--Using Data-Driven Row-Level Security
--*****
----------------------------------------------------------------------------------------------------------

CREATE TABLE Products.ProductSecurity
(
    ProductType varchar(20), --at this point you probably will create a
                             --ProductType domain table, but this keeps the
                             --example a bit simpler
    DatabaseRole    sysname,
    CONSTRAINT PKProductsSecurity PRIMARY KEY(ProductType, DatabaseRole)
);

INSERT INTO Products.ProductSecurity(ProductType, DatabaseRole)
VALUES ('widget','public');
GO

ALTER VIEW Products.ProductSelective
AS
SELECT Product.ProductId, Product.ProductCode, Product.Description,
       Product.UnitPrice, Product.ActualCost, Product.ProductType
FROM   Products.Product as Product
         JOIN Products.ProductSecurity as ProductSecurity
            ON  (Product.ProductType = ProductSecurity.ProductType
                AND IS_MEMBER(ProductSecurity.DatabaseRole) = 1)
                OR IS_MEMBER('db_owner') = 1; --don't leave out the dbo!
GO

----------------------------------------------------------------------------------------------------------
--*****
--Row-Level Security and Impersonation
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA RLSDemo;
GO
CREATE TABLE RLSDemo.TestRowLevelChaining
(
        Value    int CONSTRAINT PKTestRowLevelChaining PRIMARY KEY
)
INSERT RLSDemo.TestRowLevelChaining (Value)
VALUES  (1),(2),(3),(4),(5);
GO

CREATE FUNCTION RowLevelSecurity.dbo_TestRowLevelChaining$SecurityPredicate 
                                        (@Value AS int) 
RETURNS TABLE WITH SCHEMABINDING 
AS RETURN (SELECT 1 AS dbo_TestRowLevelChaining$SecurityPredicate 
            WHERE  @Value > 3 OR  USER_NAME() = 'dbo');
GO

CREATE SECURITY POLICY 
    RowLevelSecurity.dbo_TestRowLevelChaining_SecurityPolicy
    ADD FILTER PREDICATE  
    RowLevelSecurity.dbo_TestRowLevelChaining$SecurityPredicate (Value)
    ON RLSDemo.TestRowLevelChaining WITH (STATE = ON, SCHEMABINDING = ON); 
GO

CREATE PROCEDURE RLSDemo.TestRowLevelChaining_asCaller
AS
SELECT * FROM RLSDemo.TestRowLevelChaining;
 GO

CREATE PROCEDURE RLSDemo.TestRowLevelChaining_asDbo
WITH EXECUTE AS 'dbo' --keeping it simple for demo.. not best practice
AS                    --but you can be sure has full rights
SELECT * FROM RLSDemo.TestRowLevelChaining;
GO

CREATE USER Bobby WITHOUT LOGIN;
GRANT EXECUTE ON RLSDemo.TestRowLevelChaining_asCaller TO Bobby;
GRANT EXECUTE ON RLSDemo.TestRowLevelChaining_asDbo TO Bobby;
GO


EXECUTE AS USER = 'Bobby'
GO
EXECUTE  RLSDemo.TestRowLevelChaining_asCaller;
GO

 EXECUTE  RLSDemo.TestRowLevelChaining_asDbo;
 GO

 ----------------------------------------------------------------------------------------------------------
 --********************************************************************************************************
 --Crossing Database Lines
 --********************************************************************************************************
 ----------------------------------------------------------------------------------------------------------

 ----------------------------------------------------------------------------------------------------------
 --Using Cross-Database Chaining
 ----------------------------------------------------------------------------------------------------------
 
 
CREATE DATABASE ExternalDb;
GO
USE ExternalDb;
GO
CREATE LOGIN Paul WITH PASSWORD = 'H(*3n1923cjqp9232';
CREATE USER  Paul FROM LOGIN Paul;
CREATE TABLE dbo.Table1 ( Value int );
GO

CREATE DATABASE LocalDb;
GO
USE LocalDb;
GO
CREATE USER Paul FROM LOGIN Paul;
GO

CREATE LOGIN ExternalLocalDbOwner WITH PASSWORD = 'kjfk34iu39zskcnn4x';
ALTER LOGIN ExternalLocalDbOwner DISABLE;
GO

ALTER AUTHORIZATION ON DATABASE::ExternalDb TO ExternalLocalDbOwner;
ALTER AUTHORIZATION ON DATABASE::LocalDb TO ExternalLocalDbOwner;
GO

SELECT name, SUSER_SNAME (owner_sid) AS owner
FROM   sys.databases
WHERE  name IN ('ExternalDb','LocalDb');
GO

CREATE PROCEDURE dbo.ExternalDb$TestCrossDatabase
AS
SELECT Value
FROM   ExternalDb.dbo.Table1;
GO
GRANT EXECUTE ON dbo.ExternalDb$TestCrossDatabase TO Paul;
GO

EXECUTE dbo.ExternalDb$TestCrossDatabase;
GO

EXECUTE AS USER = 'Paul';
GO
EXECUTE dbo.ExternalDb$TestCrossDatabase;
GO
REVERT;
GO

ALTER DATABASE LocalDb
   SET DB_CHAINING ON;
ALTER DATABASE LocalDb
   SET TRUSTWORTHY ON;

--It does not need to be TRUSTWORTHY since it is not reaching out
ALTER DATABASE externalDb 
   SET DB_CHAINING ON;
GO

EXECUTE AS USER = 'Paul';
GO
EXECUTE dbo.ExternalDb$TestCrossDatabase;
GO
REVERT;
GO

SELECT name, is_trustworthy_on, is_db_chaining_on
FROM   sys.databases
WHERE  name IN ('ExternalDb','LocalDb');
GO

ALTER DATABASE LocalDB SET CONTAINMENT = PARTIAL;
GO

EXECUTE AS USER = 'Paul';
go
EXECUTE dbo.ExternalDb$TestCrossDatabase;
GO
REVERT;
GO


CREATE USER ContainedPaul WITH PASSWORD = '2k23k49(H23H2';
GO 
GRANT EXECUTE ON dbo.ExternalDb$TestCrossDatabase to ContainedPaul;
GO

EXECUTE AS USER = 'ContainedPaul';
GO
USE ExternalDb;
GO

EXECUTE dbo.ExternalDb$TestCrossDatabase;
GO
REVERT;
GO


SELECT  OBJECT_NAME(major_id) AS object_name, statement_line_number, 
        statement_type, feature_name, feature_type_name
FROM    sys.dm_db_uncontained_entities 
WHERE   class_desc = 'OBJECT_OR_COLUMN';
GO

SELECT  USER_NAME(major_id) AS USER_NAME
FROM    sys.dm_db_uncontained_entities 
WHERE   class_desc = 'DATABASE_PRINCIPAL'
  AND   USER_NAME(major_id) <> 'dbo';
GO

DROP USER ContainedPaul;
GO
USE Master;
GO
ALTER DATABASE LocalDB  SET CONTAINMENT = NONE;
GO
USE LocalDb;
GO

----------------------------------------------------------------------------------------------------------
--Using Impersonation to Cross Database Lines
----------------------------------------------------------------------------------------------------------
ALTER DATABASE LocalDb
   SET DB_CHAINING OFF;
ALTER DATABASE LocalDb
   SET TRUSTWORTHY ON;

ALTER DATABASE ExternalDb
   SET DB_CHAINING OFF;
GO


CREATE PROCEDURE dbo.ExternalDb$testCrossDatabase_Impersonation
WITH EXECUTE AS SELF 
--as procedure creator, who is the same as the db owner
AS
SELECT Value
FROM   ExternalDb.dbo.Table1;
GO
GRANT EXECUTE ON dbo.ExternalDb$TestCrossDatabase_Impersonation to Paul;
GO

EXECUTE AS USER = 'Paul';
GO
EXECUTE dbo.ExternalDb$TestCrossDatabase_Impersonation;
GO
REVERT;
GO

ALTER DATABASE localDb  SET TRUSTWORTHY OFF;
GO
EXECUTE dbo.ExternalDb$TestCrossDatabase_Impersonation;
GO


ALTER DATABASE LocalDb  SET TRUSTWORTHY ON;
GO
ALTER DATABASE LocalDB  SET CONTAINMENT = PARTIAL;
GO
CREATE USER ContainedPaul WITH PASSWORD = 'Nasty1$';
GO 
GRANT EXECUTE ON 
    ExternalDb$TestCrossDatabase_Impersonation TO ContainedPaul;
GO


EXECUTE AS USER = 'ContainedPaul';
GO
EXECUTE dbo.ExternalDb$TestCrossDatabase_Impersonation;
GO
REVERT;
GO

DROP USER ContainedPaul;
GO
USE Master;
GO
ALTER DATABASE LocalDB  SET CONTAINMENT = NONE;
GO
USE LocalDb;

----------------------------------------------------------------------------------------------------------
--Using a Certificate-Based Trust
----------------------------------------------------------------------------------------------------------
USE LocalDb;
GO
ALTER DATABASE LocalDb
   SET TRUSTWORTHY OFF;
GO


SELECT name,
       SUSER_SNAME(owner_sid) AS owner,
       is_trustworthy_on, is_db_chaining_on
FROM   sys.databases 
WHERE name IN ('LocalDb','ExternalDb');
GO


CREATE PROCEDURE dbo.ExternalDb$TestCrossDatabase_Certificate
AS
SELECT Value
FROM   ExternalDb.dbo.Table1;
GO
GRANT EXECUTE on dbo.ExternalDb$TestCrossDatabase_Certificate to Paul;
GO


CREATE CERTIFICATE ProcedureExecution 
                        ENCRYPTION BY PASSWORD = 'jsaflajOIo9jcCMd;SdpSljc'
 WITH SUBJECT =
         'Used to sign procedure:ExternalDb$TestCrossDatabase_Certificate';
GO

ADD SIGNATURE TO dbo.ExternalDb$TestCrossDatabase_Certificate
     BY CERTIFICATE ProcedureExecution 
        WITH PASSWORD = 'jsaflajOIo9jcCMd;SdpSljc';
GO

BACKUP CERTIFICATE ProcedureExecution 
                  TO FILE = 'c:\temp\procedureExecution.cer';
GO

USE ExternalDb;
GO
CREATE CERTIFICATE ProcedureExecution 
                  FROM FILE = 'c:\temp\procedureExecution.cer';
GO

CREATE USER ProcCertificate FOR CERTIFICATE ProcedureExecution;
GO
GRANT SELECT on dbo.Table1 TO ProcCertificate;
GO

USE LocalDb;
GO
EXECUTE AS LOGIN = 'Paul';
EXECUTE dbo.ExternalDb$TestCrossDatabase_Certificate;
GO

REVERT;
GO
USE MASTER;
GO
DROP DATABASE ExternalDb;
DROP DATABASE LocalDb;
GO
USE ClassicSecurityExample;

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Obfuscating Data
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Using Dynamic Data Masking to Hide Data from Users
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Demo; 
GO 
CREATE TABLE Demo.Person 
--warning, I am using very small column datatypes in this 
--example to make looking at the output easier, not as proper sizes
( 
    PersonId    int NOT NULL CONSTRAINT PKPerson PRIMARY KEY, 
    FirstName    nvarchar(10) NULL, 
    LastName    nvarchar(10) NULL, 
    PersonNumber varchar(10) NOT NULL, 
    StatusCode    varchar(10) CONSTRAINT DFLTPersonStatus DEFAULT ('New') 
          CONSTRAINT CHKPersonStatus 
                        CHECK (StatusCode in ('Active','Inactive','New')), 
    EmailAddress nvarchar(40) NULL, 
    InceptionTIme date NOT NULL, --Time we first saw this person. Usually 
                                 -- the row create time, but not always 
    -- YachtCount is a number that I didn't feel could insult anyone of any        
    -- origin, ability, etc that I could put in this table 
    YachtCount   tinyint NOT NULL 
                   CONSTRAINT DFLTPersonYachtCount DEFAULT (0) 
                   CONSTRAINT CHKPersonYachtCount CHECK (YachtCount >= 0), 
);
GO

ALTER TABLE Demo.Person ALTER COLUMN PersonNumber 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN StatusCode 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN EmailAddress 
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN InceptionTime
    ADD MASKED WITH (Function = 'default()'); 
ALTER TABLE Demo.Person ALTER COLUMN YachtCount 
    ADD MASKED WITH (Function = 'default()'); 
GO

INSERT INTO Demo.Person (PersonId,FirstName,LastName,PersonNumber, 
                   StatusCode, EmailAddress, InceptionTime,YachtCount) 
VALUES(1,'Fred','Washington','0000000014','Active',
       'frew@ttt.net','1/1/1959',0), 
(2,'Barney','Lincoln','0000000032','Active','barl@aol.com',
'8/1/1960',1), 
(3,'Wilma','Reagan','0000000102','Active',NULL, '1/1/1959', 1);
GO

CREATE USER MaskedMarauder WITHOUT LOGIN;
GRANT SELECT ON Demo.Person TO MaskedMarauder;
GO

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person;

EXECUTE AS USER = 'MaskedMarauder';

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person;

REVERT;

GO


ALTER TABLE Demo.Person ALTER COLUMN EmailAddress 
    ADD MASKED WITH (Function = 'email()');
GO

EXECUTE AS USER = 'MaskedMarauder';

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person;

REVERT;

GO

ALTER TABLE Demo.Person ALTER COLUMN YachtCount 
    ADD MASKED WITH (Function = 'random(1,100)'); 
    --makes the value between 1 and 100.

EXECUTE AS USER = 'MaskedMarauder';

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person;

REVERT;

GO


ALTER TABLE Demo.Person ALTER COLUMN PersonNumber 
    ADD MASKED WITH (Function = 'partial(1,"-------",2)'); 
    --note double quotes on the text

ALTER TABLE Demo.Person ALTER COLUMN StatusCode 
    ADD MASKED WITH (Function = 'partial(0,"Unknown",0)');

EXECUTE AS USER = 'MaskedMarauder';

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person;

REVERT;

GO


EXECUTE AS USER = 'MaskedMarauder';

SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person
WHERE  Person.PersonNumber = '0-------14';

GO


SELECT PersonId, PersonNumber, StatusCode, EmailAddress, 
       InceptionTime, YachtCount
FROM   Demo.Person
WHERE  Person.PersonNumber = '0000000014';

REVERT;

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Autiding SQL Server Use
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Defining an Audit Specification
--*****
----------------------------------------------------------------------------------------------------------



USE master;
GO
CREATE SERVER AUDIT ProSQLServerDatabaseDesign_Audit TO FILE                      
--choose your own directory, I expect most people
--have a temp directory on their system drive of their demo machine
(     FILEPATH = N'c:\temp\' 
      ,MAXSIZE = 15 MB --of each file
      ,MAX_ROLLOVER_FILES = 0 --unlimited
)
WITH
(
     ON_FAILURE = SHUTDOWN --if the file cannot be written to,
                           --shut down the server
);
GO

CREATE SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF); --disabled. I will enable it later
GO

ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    ADD (SERVER_PRINCIPAL_CHANGE_GROUP);
GO

USE ClassicSecurityExample;
GO
CREATE DATABASE AUDIT SPECIFICATION
                   ProSQLServerDatabaseDesign_Database_Audit
    FOR SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = OFF);
GO

ALTER DATABASE AUDIT SPECIFICATION
    ProSQLServerDatabaseDesign_Database_Audit
    ADD (SELECT ON Products.Product BY Employee, Manager),
    ADD (SELECT ON Products.AllProducts BY Employee, Manager);
GO

----------------------------------------------------------------------------------------------------------
--Enabling an Audit Specification
----------------------------------------------------------------------------------------------------------

USE master;
GO
ALTER SERVER AUDIT ProSQLServerDatabaseDesign_Audit
    WITH (STATE = ON);

ALTER SERVER AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Server_Audit
    WITH (STATE = ON);
GO

USE ClassicSecurityExample;
GO
ALTER DATABASE AUDIT SPECIFICATION ProSQLServerDatabaseDesign_Database_Audit
    WITH (STATE = ON);
GO

----------------------------------------------------------------------------------------------------------
--Viewing the Audit Trail
----------------------------------------------------------------------------------------------------------
CREATE LOGIN MrSmith WITH PASSWORD = 'A very g00d password!';
GO
USE ClassicSecurityExample;
GO
EXECUTE AS USER = 'Manager'; --existed from earlier examples
GO
SELECT *
FROM   Products.Product;
GO
SELECT  *
FROM    Products.AllProducts; --Permissions will fail
GO
REVERT
GO
EXECUTE AS USER = 'Employee'; --existed from earlier examples
GO
SELECT  *
FROM    Products.AllProducts; --Permissions will fail
GO
REVERT;
GO


SELECT event_time, succeeded,
       database_principal_name, statement
FROM sys.fn_get_audit_file ('c:\temp\*', DEFAULT, DEFAULT);
GO

----------------------------------------------------------------------------------------------------------
--*****
--Viewing the Audit Configuration
--*****
----------------------------------------------------------------------------------------------------------

SELECT  sas.name AS audit_specification_name,
        audit_action_name
FROM    sys.server_audits AS sa
          JOIN sys.server_audit_specifications AS sas
             ON sa.audit_guid = sas.audit_guid
          JOIN sys.server_audit_specification_details AS sasd
             ON sas.server_specification_id = sasd.server_specification_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit';

GO

SELECT audit_action_name,dp.name AS [principal],
       SCHEMA_NAME(o.schema_id) + '.' + o.name AS object
FROM   sys.server_audits AS sa
         JOIN sys.database_audit_specifications AS sas
             ON sa.audit_guid = sas.audit_guid
         JOIN sys.database_audit_specification_details AS sasd
             ON sas.database_specification_id = 
                           sasd.database_specification_id
         JOIN sys.database_principals AS dp
             ON dp.principal_id = sasd.audited_principal_id
         JOIN sys.objects AS o
             ON o.object_id = sasd.major_id
WHERE  sa.name = 'ProSQLServerDatabaseDesign_Audit'
  and  sasd.minor_id = 0; --need another query for column level audits
GO

