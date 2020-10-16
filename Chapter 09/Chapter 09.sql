--this statement prevents you from running the entire file accidentally when you have 
--sqlcmd mode turned on, which I do by default
EXIT

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Desirable Patterns
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Uniqueness Techniques
--*****
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--Selective Uniqueness
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA HumanResources;
GO
CREATE TABLE HumanResources.Employee
(
    EmployeeId int IDENTITY(1,1) CONSTRAINT PKEmployee primary key,
    EmployeeNumber char(5) NOT NULL
           CONSTRAINT AKEmployee_EmployeeNumber UNIQUE,
    --skipping other columns you would likely have
    InsurancePolicyNumber char(10) NULL
);
GO


--Filtered Alternate Key (AKF)
CREATE UNIQUE INDEX AKFEmployee_InsurancePolicyNumber ON 
       HumanResources.Employee(InsurancePolicyNumber)
               WHERE InsurancePolicyNumber IS NOT NULL;
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111');
GO

--causes error
INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002','1111111111');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0002','2222222222');
GO

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0003','3333333333'),
       ('A0004',NULL),
       ('A0005',NULL);
GO

SELECT *
FROM   HumanResources.Employee;
GO



CREATE SCHEMA Account;
GO
CREATE TABLE Account.Contact
(
    ContactId   varchar(10) NOT NULL,
    AccountNumber   char(5) NOT NULL, --would be FK in full example
    PrimaryContactFlag bit NOT NULL,
    CONSTRAINT PKContact PRIMARY KEY(ContactId, AccountNumber)
);

GO

CREATE UNIQUE INDEX AKFContact_PrimaryContact
            ON Account.Contact(AccountNumber) WHERE PrimaryContactFlag = 1;

GO

--second row causes error
INSERT INTO Account.Contact
VALUES ('bob','11111',1);
GO
INSERT INTO Account.Contact
VALUES ('fred','11111',1);
GO

--Using very simplistic error handling
BEGIN TRY
  BEGIN TRANSACTION;

  UPDATE Account.Contact
  SET PrimaryContactFlag = 0
  WHERE  accountNumber = '11111';

  INSERT Account.Contact
  VALUES ('fred','11111', 1);

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
   ROLLBACK TRANSACTION;
   THROW; --just show the error that occurred
END CATCH;
GO

----------------------------------------------------------------------------------------------------------
--Bulk Uniqueness
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Lego;
GO
CREATE TABLE Lego.Build
(
        BuildId int CONSTRAINT PKBuild PRIMARY KEY,
        Name    varchar(30) NOT NULL CONSTRAINT AKBuild_Name UNIQUE,
        LegoCode varchar(5) NULL, --five character set number
        InstructionsURL varchar(255) NULL 
        --where you can get the PDF of the instructions
);
GO

CREATE TABLE Lego.BuildInstance
(
        BuildInstanceId Int CONSTRAINT PKBuildInstance PRIMARY KEY ,
        BuildId Int CONSTRAINT FKBuildInstance$isAVersionOf$LegoBuild 
                        REFERENCES Lego.Build (BuildId),
        BuildInstanceName varchar(30) NOT NULL, --brief description of item 
        Notes varchar(1000)  NULL, 
        --longform notes. These could describe modifications 
                                   --for the instance of the model
        CONSTRAINT AKBuildInstance UNIQUE(BuildId, BuildInstanceName)
);
GO


CREATE TABLE Lego.Piece
(
        PieceId int CONSTRAINT PKPiece PRIMARY KEY,
        Type    varchar(15) NOT NULL,
        Name    varchar(30) NOT NULL,
        Color   varchar(20) NULL,
        Width int NULL,
        Length int NULL,
        Height int NULL,
        LegoInventoryNumber int NULL,
        OwnedCount int NOT NULL,
        CONSTRAINT AKPiece_Definition 
                     UNIQUE (Type,Name,Color,Width,Length,Height),
        CONSTRAINT AKPiece_LegoInventoryNumber UNIQUE (LegoInventoryNumber)
);
GO

CREATE TABLE Lego.BuildInstancePiece
(
        BuildInstanceId int NOT NULL,
        PieceId int NOT NULL,
        AssignedCount int NOT NULL,
        CONSTRAINT PKBuildInstancePiece 
                     PRIMARY KEY (BuildInstanceId, PieceId)
);
GO

INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (1,'Small Car','3177',
'https://www.brickowl.com/catalog/lego-small-car-set-3177-instructions/viewer');
GO

INSERT Lego.BuildInstance 
       (BuildInstanceId, BuildId, BuildInstanceName, Notes)
VALUES (1,1,'Small Car for Book',NULL);
GO

INSERT Lego.Piece (PieceId, Type, Name, Color, Width, Length, Height, 
                   LegoInventoryNumber, OwnedCount)
VALUES (1, 'Brick','Basic Brick','White',1,3,1,'362201',20),
           (2, 'Slope','Slope','White',1,1,1,'4504369',2),
           (3, 'Tile','Groved Tile','White',1,2,NULL,'306901',10),
           (4, 'Plate','Plate','White',2,2,NULL,'302201',20),
           (5, 'Plate','Plate','White',1,4,NULL,'371001',10),
           (6, 'Plate','Plate','White',2,4,NULL,'302001',1),
           (7, 'Bracket','1x2 Bracket with 2x2','White',2,1,2,'4277926',2),
           (8, 'Mudguard','Vehicle Mudguard','White',2,4,NULL,'4289272',1),
           (9, 'Door','Right Door','White',1,3,1,'4537987',1),
           (10,'Door','Left Door','White',1,3,1,'45376377',1),
           (11,'Panel','Panel','White',1,2,1,'486501',1),
           (12,'Minifig Part',
               'Minifig Torso , Sweatshirt','White',NULL,NULL,
                NULL,'4570026',1),
           (13,'Steering Wheel','Steering Wheel','Blue',1,2,NULL,'9566',1),
           (14,'Minifig Part',
               'Minifig Head, Male Brown Eyes','Yellow',NULL, NULL, 
                NULL,'4570043',1),
           (15,'Slope','Slope','Black',2,1,2,'4515373',2),
           (16,'Mudguard','Vehicle Mudgard',
               'Black',2,4,NULL,'4195378',1),
           (17,'Tire',
               'Vehicle Tire,Smooth','Black',NULL,NULL,NULL,'4508215',4),
           (18,'Vehicle Base','Vehicle Base','Black',4,7,2,'244126',1),
           (19,'Wedge','Wedge (Vehicle Roof)','Black',1,4,4,'4191191',1),
           (20,'Plate','Plate','Lime Green',1,2,NULL,'302328',4),
           (21,'Minifig Part','Minifig Legs',
               'Lime Green',NULL,NULL,NULL,'74040',1),
           (22,'Round Plate','Round Plate','Clear',1,1,NULL,'3005740',2),
           (23,'Plate','Plate','Transparent Red',1,2,NULL,'4201019',1),
           (24,'Briefcase','Briefcase',
               'Reddish Brown',NULL,NULL,NULL,'4211235', 1),
           (25,'Wheel','Wheel',
               'Light Bluish Gray',NULL,NULL,NULL,'4211765',4),
           (26,'Tile','Grilled Tile','Dark Bluish Gray',1,2,NULL,
               '4210631', 1),
           (27,'Minifig Part','Brown Minifig Hair',
               'Dark Brown',NULL,NULL,NULL,
               '4535553', 1),
           (28,'Windshield','Windshield',
               'Transparent Black',3,4,1,'4496442',1),
           --and a few extra pieces to make the queries more interesting
           (29,'Baseplate','Baseplate','Green',16,24,NULL,'3334',4),
           (30,'Brick','Basic Brick','White',4,6,NULL,'2356',10);
GO

INSERT INTO Lego.BuildInstancePiece 
       (BuildInstanceId, PieceId, AssignedCount)
VALUES (1,1,2),(1,2,2),(1,3,1),(1,4,2),(1,5,1),(1,6,1),(1,7,2),
       (1,8,1),(1,9,1),(1,10,1),(1,11,1),(1,12,1),(1,13,1),(1,14,1),
       (1,15,2),(1,16,1),(1,17,4),(1,18,1),(1,19,1),(1,20,4),(1,21,1),
       (1,22,2),(1,23,1),(1,24,1),(1,25,4),(1,26,1),(1,27,1),(1,28,1);
GO

INSERT Lego.Build (BuildId, Name, LegoCode, InstructionsURL)
VALUES  (2,'Brick Triangle',NULL,NULL);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, 
                          BuildInstanceName, Notes)
VALUES (2,2,'Brick Triangle For Book','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId, 
                                     AssignedCount)
VALUES (2,1,3);
GO
INSERT Lego.BuildInstance (BuildInstanceId, BuildId, BuildInstanceName, 
                           Notes)
VALUES (3,2,'Brick Triangle For Book2','Simple build with 3 white bricks');
GO
INSERT INTO Lego.BuildInstancePiece (BuildInstanceId, PieceId,                   
                                     AssignedCount)
VALUES (3,1,3);
GO

SELECT COUNT(*) AS PieceCount, SUM(OwnedCount) AS InventoryCount
FROM  Lego.Piece;
GO

SELECT Type, COUNT(*) AS TypeCount, SUM(OwnedCount) AS InventoryCount
FROM  Lego.Piece
GROUP BY Type;
GO

SELECT CASE WHEN GROUPING(Piece.Type) = 1 
            THEN '--Total--' ELSE Piece.Type END AS PieceType,
       Piece.Color,Piece.Height, Piece.Width, Piece.Length,
       SUM(BuildInstancePiece.AssignedCount) AS AssignedCount
FROM   Lego.Build
                 JOIN Lego.BuildInstance        
                        ON Build.BuildId = BuildInstance.BuildId
                 JOIN Lego.BuildInstancePiece
                        ON BuildInstance.BuildInstanceId = 
                                    BuildInstancePiece.BuildInstanceId
                 JOIN Lego.Piece
                        ON BuildInstancePiece.PieceId = Piece.PieceId
WHERE  Build.Name = 'Small Car'
  AND  BuildInstanceName = 'Small Car for Book'
GROUP BY GROUPING SETS((Piece.Type,Piece.Color, 
                            Piece.Height, Piece.Width, Piece.Length),
                       ());
GO

WITH AssignedPieceCount
AS (
SELECT PieceId, SUM(AssignedCount) AS TotalAssignedCount
FROM   Lego.BuildInstancePiece
GROUP  BY PieceId )

SELECT Type, Name,  Width, Length,Height, 
       Piece.OwnedCount - Coalesce(TotalAssignedCount,0) AS AvailableCount
FROM   Lego.Piece
                 LEFT OUTER JOIN AssignedPieceCount
                        on Piece.PieceId =  AssignedPieceCount.PieceId
WHERE Piece.OwnedCount - Coalesce(TotalAssignedCount,0) > 0; 
GO

----------------------------------------------------------------------------------------------------------
--Range Uniqueness
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Office;
GO
CREATE TABLE Office.Doctor
(
        DoctorId        int NOT NULL CONSTRAINT PKDoctor PRIMARY KEY,
        DoctorNumber char(5) NOT NULL 
                             CONSTRAINT AKDoctor_DoctorNumber UNIQUE
);
CREATE TABLE Office.Appointment
(
        AppointmentId   int NOT NULL CONSTRAINT PKAppointment PRIMARY KEY,
        --real situation would include room, patient, etc, 
        DoctorId        int NOT NULL,
        StartTime       datetime2(0), --precision to the second
        EndTime         datetime2(0),
        CONSTRAINT 
               AKAppointment_DoctorStartTime UNIQUE (DoctorId,StartTime),
        CONSTRAINT AKAppointment_DoctorEndTime UNIQUE (DoctorId,EndTime),
        --this covers one very specific requirement Starts before Ends
        CONSTRAINT CHKAppointment_StartBeforeEnd 
                                             CHECK (StartTime <= EndTime),
        CONSTRAINT FKDoctor$IsAssignedTo$OfficeAppointment 
                FOREIGN KEY (DoctorId) REFERENCES Office.Doctor (DoctorId)
);
GO


INSERT INTO Office.Doctor (DoctorId, DoctorNumber)
VALUES (1,'00001'),(2,'00002');

INSERT INTO Office.Appointment
VALUES (1,1,'20200712 14:00','20200712 14:59:59'),
       (2,1,'20200712 15:00','20200712 16:59:59'),
       (3,2,'20200712 8:00','20200712 11:59:59'),
       (4,2,'20200712 13:00','20200712 17:59:59'),
       (5,2,'20200712 14:00','20200712 14:59:59'); 
       --offensive item for demo, conflicts with 4
GO

SELECT Appointment.AppointmentId,
       Acheck.AppointmentId AS ConflictingAppointmentId
FROM   Office.Appointment
        JOIN Office.Appointment AS ACheck
          ON Appointment.DoctorId = ACheck.DoctorId
     /*1*/   AND Appointment.AppointmentId <> ACheck.AppointmentId         
     /*2*/   AND (Appointment.StartTime BETWEEN ACheck.StartTime AND 
                                                           ACheck.EndTime  
     /*3*/        OR Appointment.EndTime BETWEEN ACheck.StartTime AND     
                                                          ACheck.EndTime
     /*4*/        OR (Appointment.StartTime < ACheck.StartTime 
                       AND Appointment.EndTime > ACheck.EndTime));
GO

DELETE FROM Office.Appointment WHERE AppointmentId = 5;
GO

CREATE TRIGGER Office.Appointment$InsertAndUpdate
ON Office.Appointment
AFTER UPDATE, INSERT AS 
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for 
   --update or delete trigger count instead of @@rowcount due to merge 
   --behavior that sets @@rowcount to a number that is equal to number of
   --merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
           
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
      --[validation section]
      --if this is an update, but they don’t change times or doctor, 
      --don’t check the data. UPDATE is always true for INSERT action
      IF UPDATE(StartTime) OR UPDATE(EndTime) OR UPDATE(DoctorId)
      BEGIN
      IF EXISTS ( SELECT *
                  FROM   Office.Appointment
                          JOIN Office.Appointment AS ACheck
                            ON Appointment.doctorId = ACheck.doctorId
                                 AND Appointment.AppointmentId <> 
                                                     ACheck.AppointmentId
                                 AND (Appointment.StartTime BETWEEN 
                                        Acheck.StartTime AND Acheck.EndTime
                                      OR Appointment.EndTime BETWEEN  
                                        Acheck.StartTime AND Acheck.EndTime
                                     OR (Appointment.StartTime < 
                                                                 
                                                       Acheck.StartTime                                                 
                                 AND Appointment.EndTime > Acheck.EndTime))
                              WHERE  EXISTS (SELECT *
                                             FROM   inserted
                                             WHERE  inserted.DoctorId = 
                                                          Acheck.DoctorId))
                   BEGIN
                     IF @rowsAffected = 1
                        SELECT @msg = 'Appointment for doctor '                                                            
                                   + doctorNumber 
                                   + ' overlapped existing appointment'
                        FROM   inserted
                                JOIN Office.Doctor
                                   ON inserted.DoctorId = Doctor.DoctorId;
                     ELSE
                         SELECT @msg = 'One of the rows caused '
                              + ' an overlapping appointment time ' 
                              + ' a doctor.';
                     THROW 50000,@msg,1;

                   END;
         END;
          --[modification section]
   END TRY
   BEGIN CATCH
          IF @@trancount > 0
              ROLLBACK TRANSACTION;
          THROW;
     END CATCH;
END;
GO

--causes error
INSERT INTO Office.Appointment
VALUES (5,1,'20200712 14:00','20200712 14:59:59');
GO

--causes error
INSERT INTO Office.Appointment
VALUES (5,1,'20200712 14:30','20200712 14:40:59');
GO

--causes error
INSERT INTO Office.Appointment
VALUES (5,1,'20200712 11:30','20200712 17:59:59');
GO

--causes error
INSERT into Office.Appointment
VALUES (5,1,'20200712 11:30','20200712 15:59:59'),
       (6,2,'20200713 10:00','20200713 10:59:59');

----------------------------------------------------------------------------------------------------------
--*****
--Historical/Temporal Data
--*****
----------------------------------------------------------------------------------------------------------
IF SCHEMA_ID('HumanResources') IS NULL
   EXECUTE ('CREATE SCHEMA HumanResources');
GO

IF OBJECT_ID('HumanResources.Employee') IS NULL 
	CREATE TABLE HumanResources.Employee
	(
		EmployeeId int IDENTITY(1,1) CONSTRAINT PKEmployee primary key,
		EmployeeNumber char(5) NOT NULL
			   CONSTRAINT AKEmployee_EmployeeNummer UNIQUE,
		InsurancePolicyNumber char(10) NULL
	);
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE OBJECT_ID = OBJECT_ID('HumanResources.Employee')
      AND name = 'AKFEmployee_InsurancePolicyNumber')
	CREATE UNIQUE INDEX AKFEmployee_InsurancePolicyNumber ON
	HumanResources.Employee(InsurancePolicyNumber)
								   WHERE InsurancePolicyNumber IS NOT NULL;
GO

ALTER TABLE HumanResources.Employee
     ADD InsurancePolicyNumberChangeTime datetime2(0);

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Using a Trigger to Capture History
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------
TRUNCATE TABLE HumanResources.Employee;

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111'),
        ('A0002','2222222222'),
        ('A0003','3333333333'),
        ('A0004',NULL),
        ('A0005',NULL),
        ('A0006',NULL);
GO

CREATE SCHEMA HumanResourcesHistory;
GO

CREATE TABLE HumanResourcesHistory.Employee
(
    --Original columns
    EmployeeId int NOT NULL,
    EmployeeNumber char(5) NOT NULL,
    InsurancePolicyNumber char(10) NULL,

    --WHEN the row was modified    
    RowModificationTime datetime2(0) NOT NULL,
    --WHAT type of modification
    RowModificationType varchar(10) NOT NULL CONSTRAINT
               CHKEmployeeSalary_RowModificationType 
                      CHECK (RowModificationType IN ('UPDATE','DELETE')),

    --tiebreaker for seeing order of changes, if rows were modified rapidly
    --use to break ties in RowModificationTime
    RowSequencerValue bigint IDENTITY(1,1) 
);
GO

CREATE TRIGGER HumanResources.Employee$HistoryManagementTrigger
ON HumanResources.Employee
AFTER UPDATE, DELETE AS --usually duplicate code in two triggers to allow
BEGIN                   --future modifications;

   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for 
   --update or delete trigger count instead of @@rowcount due to merge 
   --behavior that sets @@rowcount to a number that is equal to number of
   --merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM deleted);

   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   DECLARE @RowModificationType char(6);
   SET @RowModificationType = CASE WHEN EXISTS (SELECT * FROM inserted) 
                                   THEN 'UPDATE' ELSE 'DELETE' END;

   BEGIN TRY
       --[validation section]
       --[modification section]
       --write deleted rows to the history table 
       INSERT  HumanResourcesHistory.Employee
               (EmployeeId,EmployeeNumber,InsurancePolicyNumber,
               RowModificationTime,RowModificationType)
       SELECT EmployeeId,EmployeeNumber,InsurancePolicyNumber, 
              SYSDATETIME(), @RowModificationType
       FROM   deleted;
   END TRY
   BEGIN CATCH
          IF @@trancount > 0
              ROLLBACK TRANSACTION;
          THROW;
     END CATCH;
END;
GO

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = '4444444444'
WHERE  EmployeeId = 4;
GO

SELECT *
FROM   HumanResources.Employee
WHERE  EmployeeId = 4;

SELECT *
FROM   HumanResourcesHistory.Employee
WHERE  EmployeeId = 4;
GO

UPDATE HumanResources.Employee
SET  InsurancePolicyNumber = 'IN' + RIGHT(InsurancePolicyNumber,8);

DELETE HumanResources.Employee
WHERE EmployeeId = 6;
GO

SELECT *
FROM   HumanResources.Employee
ORDER BY EmployeeId;

--limiting output for formatting purposes
SELECT EmployeeId, InsurancePolicyNumber, 
       RowModificationTime, RowModificationType
FROM   HumanResourcesHistory.Employee
ORDER  BY EmployeeId,RowModificationTime,RowSequencerValue;
GO

----------------------------------------------------------------------------------------------------------
--Using Temporal Extensions to Manage History
----------------------------------------------------------------------------------------------------------

TRUNCATE TABLE HumanResources.Employee;

INSERT INTO HumanResources.Employee (EmployeeNumber, InsurancePolicyNumber)
VALUES ('A0001','1111111111'),
       ('A0002','2222222222'),
       ('A0003','3333333333'),
       ('A0004',NULL),
       ('A0005',NULL),
       ('A0006',NULL);
GO
DROP TABLE IF EXISTS HumanResourcesHistory.Employee;
DROP TRIGGER IF EXISTS HumanResources.Employee$HistoryManagementTrigger;
GO

--
--Configuring Temporal Extensions
--

ALTER TABLE HumanResources.Employee
ADD
    RowStartTime datetime2(1) GENERATED ALWAYS AS ROW START NOT NULL 
         --HIDDEN can be specified 
          --so temporal columns don't show up in SELECT * queries
         --This default will start the history of all existing rows at the 
         --current time (system uses UTC time for these values)
         --this default sets the start to NOW… use the best time
         --for your need. Also, you may get errors as SYSUTCDATETIME()
         --may produce minutely future times on occaions
        CONSTRAINT DFLTDelete1 DEFAULT (SYSUTCDATETIME()),
    RowEndTime datetime2(1) GENERATED ALWAYS AS ROW END NOT NULL --HIDDEN
          --data needs to be the max for the datatype
        CONSTRAINT DFLTDelete2 
            DEFAULT (CAST('9999-12-31 23:59:59.9' AS datetime2(1)))
  , PERIOD FOR SYSTEM_TIME (RowStartTime, RowEndTime);
GO

--DROP the constraints that are just there to backfill data 
ALTER TABLE HumanResources.Employee DROP CONSTRAINT DFLTDelete1;
ALTER TABLE HumanResources.Employee DROP CONSTRAINT DFLTDelete2;
GO

ALTER TABLE HumanResources.Employee
         SET (SYSTEM_VERSIONING = ON);
GO

SELECT  tables.object_id AS BaseTableObject, 
        CONCAT(historySchema.name,'.',historyTable.name) AS HistoryTable
FROM    sys.tables
          JOIN sys.schemas
              ON schemas.schema_id = tables.schema_id
          LEFT OUTER JOIN sys.tables AS historyTable
                 JOIN sys.schemas AS historySchema
                       ON historySchema.schema_id = historyTable.schema_id
            ON TABLES.history_table_id = historyTable.object_id
WHERE   schemas.name = 'HumanResources'
  AND   tables.name = 'Employee';
GO

ALTER TABLE HumanResources.Employee
         SET (SYSTEM_VERSIONING = OFF);
DROP TABLE HumanResources.MSSQL_TemporalHistoryFor_581577110;
GO

ALTER TABLE HumanResources.Employee --must be in the same database
SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = 
                                    HumanResourcesHistory.Employee));
GO

SELECT  tables.object_id AS BaseTableObject, 
        CONCAT(historySchema.name,'.',historyTable.name) AS HistoryTable
FROM    sys.tables
          JOIN sys.schemas
              ON schemas.schema_id = tables.schema_id
          LEFT OUTER JOIN sys.tables AS historyTable
                 JOIN sys.schemas AS historySchema
                       ON historySchema.schema_id = historyTable.schema_id
            ON TABLES.history_table_id = historyTable.object_id
WHERE   schemas.name = 'HumanResources'
  AND   tables.name = 'Employee';
GO

SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResources.Employee;
GO

SELECT *
FROM   HumanResources.Employee FOR SYSTEM_TIME AS OF '2020-05-27';
GO

SELECT *
FROM   HumanResources.Employee FOR SYSTEM_TIME AS OF '2020-05-28';
GO


DECLARE @asOfTime datetime2(1) = '2020-05-28';
 
SET @asOfTime = @asOfTime 
         --first set the variable to the time zone you are in
         AT TIME ZONE 'Eastern Standard Time' 
         AT TIME ZONE 'UTC' --then convert to UTC

SELECT EmployeeId, RowStartTime,
       CAST(RowStartTime AT TIME ZONE 'UTC' --set to UTC, then Local
            AT TIME ZONE 'Eastern Standard Time' AS datetime2(1)) 
            AS RowStartTimeLocal
FROM   HumanResources.Employee FOR SYSTEM_TIME AS OF @asOfTime;

--
--Delaing with Temporal Data One Row At A Time
--

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = '4444444444'
WHERE  EmployeeId = 4;
GO

SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResources.Employee
WHERE  Employee.EmployeeId = 4;
GO

SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResources.Employee FOR SYSTEM_TIME AS OF '2020-05-28 00:11:07'
WHERE  Employee.EmployeeId = 4;
GO

SELECT *
FROM   HumanResources.Employee FOR SYSTEM_TIME ALL
ORDER  BY EmployeeId, RowStartTime;
GO


DELETE HumanResources.Employee
WHERE  EmployeeId = 6;
GO

SELECT *
FROM   HumanResources.Employee FOR SYSTEM_TIME ALL
WHERE  EmployeeId = 6
ORDER  BY EmployeeId, RowStartTime;
GO

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = InsurancePolicyNumber 
WHERE  EmployeeId = 4;
GO

SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResources.Employee FOR SYSTEM_TIME ALL
WHERE  EmployeeId = 4
ORDER  BY EmployeeId, RowStartTime;
GO

UPDATE HumanResources.Employee
SET    EmployeeNumber = EmployeeNumber
WHERE  EmployeeId = 4;
GO 5

SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResources.Employee FOR SYSTEM_TIME ALL
WHERE  EmployeeId = 4
ORDER  BY EmployeeId, RowStartTime;
GO
SELECT Employee.EmployeeId, Employee.InsurancePolicyNumber AS PolicyNumber, 
       Employee.RowStartTime, Employee.RowEndTime
FROM   HumanResourcesHistory.Employee
WHERE  EmployeeId = 4
  AND  RowStartTime = RowEndTime;


--
--Dealing with Multiple Rows in One or More Tables
--
BEGIN TRANSACTION;
UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = CONCAT('IN',RIGHT(InsurancePolicyNumber,8))
WHERE  EmployeeId = 1;

WAITFOR DELAY '00:00:01';

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = CONCAT('IN',RIGHT(InsurancePolicyNumber,8))
WHERE  EmployeeId = 2;

WAITFOR DELAY '00:00:01';

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = CONCAT('IN',RIGHT(InsurancePolicyNumber,8))
WHERE  EmployeeId = 3;

WAITFOR DELAY '00:00:01';

UPDATE HumanResources.Employee
SET    InsurancePolicyNumber = CONCAT('IN',RIGHT(InsurancePolicyNumber,8))
WHERE  EmployeeId = 4;

COMMIT TRANSACTION;
GO

SELECT *
FROM   HumanResources.Employee 
WHERE  InsurancePolicyNumber IS NOT NULL
ORDER BY EmployeeId;

--
--Setting/Rewriting History
--

SELECT MIN(RowStartTime)
FROM   HumanResources.Employee FOR SYSTEM_TIME ALL;
GO

ALTER TABLE HumanResources.Employee
         SET (SYSTEM_VERSIONING = OFF);
GO

--Rows that have been modified
UPDATE HumanResourcesHistory.Employee
SET    RowStartTime = '2020-01-01 00:00:00.0'
WHERE  RowStartTime = '2020-08-18 00:43:32.4'; 
--value from previous select if you are following along in the home game
GO

INSERT INTO HumanResourcesHistory.Employee (EmployeeId, EmployeeNumber, 
                         InsurancePolicyNumber,RowStartTime, RowEndTime)
SELECT EmployeeId, EmployeeNumber, InsurancePolicyNumber, 
       '2020-01-01 00:00:00.0', RowStartTime 
     --use the rowStartTime in the row for the endTime of the history
FROM   HumanResources.Employee
WHERE  NOT EXISTS (SELECT *
                   FROM   HumanResourcesHistory.Employee AS HistEmployee
                   WHERE  HistEmployee.EmployeeId = Employee.EmployeeId);
GO
SELECT Employee.EmployeeId, Employee.RowEndTime
FROM   HumanResourcesHistory.Employee
WHERE  RowStartTime = '2020-01-01 00:00:00.0'
ORDER BY EmployeeId;
GP

ALTER TABLE HumanResources.Employee
        SET (SYSTEM_VERSIONING = ON 
                 (HISTORY_TABLE = HumanResourcesHistory.Employee));
GO

SELECT *
FROM  HumanResources.Employee FOR SYSTEM_TIME AS OF '2020-01-01 00:00:00.0'
ORDER BY EmployeeId;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Images, Documents, and Other Files
--*****
----------------------------------------------------------------------------------------------------------

EXEC sp_configure 'filestream_access_level', 2;
RECONFIGURE;
GO

CREATE DATABASE FileStorageDemo; --uses basic defaults from model database
GO
USE FileStorageDemo;
GO
--will cover filegroups more in the chapter 11 on structures
ALTER DATABASE FileStorageDemo ADD
        FILEGROUP FilestreamData CONTAINS FILESTREAM;
GO


ALTER DATABASE FileStorageDemo ADD FILE (
       NAME = FilestreamDataFile1,
       FILENAME = 'c:\sql\filestream') 
    --directory cannot yet exist and SQL account must have access to drive.
TO FILEGROUP FilestreamData;
GO

CREATE SCHEMA Demo;
GO
CREATE TABLE Demo.TestSimpleFileStream
(
        TestSimpleFilestreamId INT NOT NULL 
                      CONSTRAINT PKTestSimpleFileStream PRIMARY KEY,
        FileStreamColumn VARBINARY(MAX) FILESTREAM NULL,
        RowGuid uniqueidentifier NOT NULL ROWGUIDCOL DEFAULT (NEWID()) 
                      CONSTRAINT AKTestSimpleFileStream_RowGuid UNIQUE
)       FILESTREAM_ON FilestreamData; 
GO

INSERT INTO Demo.TestSimpleFileStream
                                  (TestSimpleFilestreamId,FileStreamColumn)
SELECT 1, CAST('This is an exciting example' AS varbinary(max));
GO


SELECT TestSimpleFilestreamId,FileStreamColumn,
       CAST(FileStreamColumn AS varchar(40)) AS FileStreamText
FROM   Demo.TestSimpleFilestream;
GO

ALTER DATABASE FileStorageDemo
        SET FILESTREAM (NON_TRANSACTED_ACCESS = FULL, 
                         DIRECTORY_NAME = N'ProSQLServerDBDesign');
GO

CREATE TABLE Demo.FileTableTest AS FILETABLE
  WITH (
        FILETABLE_DIRECTORY = 'FileTableTest',
        FILETABLE_COLLATE_FILENAME = database_default
        );
GO

INSERT INTO Demo.FiletableTest(name, is_directory) 
VALUES ( 'Project 1', 1);
GO

SELECT stream_id, file_stream, name
FROM   Demo.FileTableTest
WHERE  name = 'Project 1';
GO

INSERT INTO Demo.FiletableTest(name, is_directory, file_stream) 
VALUES ( 'Test.Txt', 0, CAST('This is some text' AS varbinary(max)));
GO

UPDATE Demo.FiletableTest
SET    path_locator = 
        path_locator.GetReparentedValue( path_locator.GetAncestor(1),
                                       (SELECT path_locator 
                                        FROM Demo.FiletableTest 
                                        WHERE name = 'Project 1' 
                                          AND parent_path_locator IS NULL
                                          AND is_directory = 1))
WHERE name = 'Test.Txt';
GO

SELECT  CONCAT(FileTableRootPath(),
                         file_stream.GetFileNamespacePath()) AS FilePath
FROM    Demo.FileTableTest
WHERE   name = 'Project 1' 
  AND   parent_path_locator is NULL
  AND   is_directory = 1;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Generalization
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Inventory;
GO
CREATE TABLE Inventory.Item
(
        ItemId  int NOT NULL IDENTITY CONSTRAINT PKItem PRIMARY KEY,
        Name    varchar(30) NOT NULL CONSTRAINT AKItemName UNIQUE,
        Type    varchar(15) NOT NULL,
        Color   varchar(15) NOT NULL,
        Description varchar(100) NOT NULL,
        ApproximateValue  numeric(12,2) NULL,
        ReceiptImage   varbinary(max) NULL,
        PhotographicImage varbinary(max) NULL
);
GO


INSERT INTO Inventory.Item
VALUES ('Den Couch','Furniture','Blue',
        'Blue plaid couch, seats 4',450.00,0x001,0x001),
       ('Den Ottoman','Furniture','Blue',
        'Blue plaid ottoman that goes with couch',  
         150.00,0x001,0x001),
       ('40 Inch Sorny TV','Electronics','Black',
        '40 Inch Sorny TV, Model R2D12, Serial Number XD49292',
         800,0x001,0x001),
        ('29 Inch JQC TV','Electronics','Black',
         '29 Inch JQC CRTVX29 TV',800,0x001,0x001),
        ('Mom''s Pearl Necklace','Jewelery','White',
         'Appraised for $1300 June of 2003. 30 inch necklace, was Mom''s',
         1300,0x001,0x001);
GO

SELECT Name, Type, Description
FROM   Inventory.Item;
GO

CREATE TABLE Inventory.JeweleryItem
(
        ItemId  int     CONSTRAINT PKJeweleryItem PRIMARY KEY
                    CONSTRAINT FKJeweleryItem$Extends$InventoryItem
                                  REFERENCES Inventory.Item(ItemId),
        QualityLevel   varchar(10) NOT NULL,
        --a case might be made to store the appraisal document, and
        --possibly a new table for appraisals. This will suffice for
        --the current example set
        AppraiserName  varchar(100) NULL,
        AppraisalValue numeric(12,2) NULL,
        AppraisalYear  char(4) NULL
);
GO
CREATE TABLE Inventory.ElectronicItem
(
        ItemId        int        CONSTRAINT PKElectronicItem PRIMARY KEY
                    CONSTRAINT FKElectronicItem$Extends$InventoryItem
                                 REFERENCES Inventory.Item(ItemId),
        BrandName  varchar(20) NOT NULL,
        ModelNumber varchar(20) NOT NULL,
        SerialNumber varchar(20) NULL
);
GO


UPDATE Inventory.Item
SET    Description = '40 Inch TV' 
WHERE  Name = '40 Inch Sorny TV';
GO
INSERT INTO Inventory.ElectronicItem 
            (ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'Sorny','R2D12','XD49393'
FROM   Inventory.Item
WHERE  Name = '40 Inch Sorny TV';
GO
UPDATE Inventory.Item
SET    Description = '29 Inch TV' 
WHERE  Name = '29 Inch JQC TV';
GO
INSERT INTO Inventory.ElectronicItem
            (ItemId, BrandName, ModelNumber, SerialNumber)
SELECT ItemId, 'JVC','CRTVX29',NULL
FROM   Inventory.Item
WHERE  Name = '29 Inch JQC TV';
GO


UPDATE Inventory.Item
SET    Description = '30 Inch Pearl Neclace' 
WHERE  Name = 'Mom''s Pearl Necklace';
GO

INSERT INTO Inventory.JeweleryItem 
      (ItemId, QualityLevel, AppraiserName, AppraisalValue,AppraisalYear )
SELECT ItemId, 'Fine','Joey Appraiser',1300,'2003'
FROM   Inventory.Item
WHERE  Name = 'Mom''s Pearl Necklace';
GO


SELECT Name, Type, Description
FROM   Inventory.Item;
GO

SELECT Item.Name, ElectronicItem.BrandName, ElectronicItem.ModelNumber, 
       ElectronicItem.SerialNumber
FROM   Inventory.ElectronicItem
         JOIN Inventory.Item
                ON Item.ItemId = ElectronicItem.ItemId;
GO

SELECT Name, Description, 
       CASE Type
          WHEN 'Electronics'
            THEN CONCAT('Brand:', COALESCE(BrandName,'_______'),
                 ' Model:',COALESCE(ModelNumber,'________'), 
                 ' SerialNumber:', COALESCE(SerialNumber,'_______'))
          WHEN 'Jewelery'
            THEN CONCAT('QualityLevel:', QualityLevel,
                 ' Appraiser:', COALESCE(AppraiserName,'_______'),
                 ' AppraisalValue:', 
              COALESCE(Cast(AppraisalValue as varchar(20)),'_______'),   
                 ' AppraisalYear:', COALESCE(AppraisalYear,'____'))
            ELSE '' END as ExtendedDescription
FROM   Inventory.Item --simple outer joins because every not item will have 
                 -- extensions but they will only have one if any extension
           LEFT OUTER JOIN Inventory.ElectronicItem
                ON Item.ItemId = ElectronicItem.ItemId
           LEFT OUTER JOIN Inventory.JeweleryItem
                ON Item.ItemId = JeweleryItem.ItemId;
GO

----------------------------------------------------------------------------------------------------------
--*****
--Storing User
--*****
----------------------------------------------------------------------------------------------------------
CREATE SCHEMA Hardware;
GO
CREATE TABLE Hardware.Equipment
(
    EquipmentId int NOT NULL
          CONSTRAINT PKEquipment PRIMARY KEY,
    EquipmentTag varchar(10) NOT NULL
          CONSTRAINT AKEquipment UNIQUE,
    EquipmentType varchar(10)
);
GO
INSERT INTO Hardware.Equipment
VALUES (1,'CLAWHAMMER','Hammer'),
       (2,'HANDSAW','Saw'),
       (3,'POWERDRILL','PowerTool');
GO

----------------------------------------------------------------------------------------------------------
--Entity-Attribute-Value (EAV)
----------------------------------------------------------------------------------------------------------

CREATE TABLE Hardware.EquipmentPropertyType
(
    EquipmentPropertyTypeId int NOT NULL
        CONSTRAINT PKEquipmentPropertyType PRIMARY KEY,
    Name varchar(15)
        CONSTRAINT AKEquipmentPropertyType UNIQUE,
    TreatAsDatatype sysname NOT NULL
);

INSERT INTO Hardware.EquipmentPropertyType
VALUES(1,'Width','numeric(10,2)'),
      (2,'Length','numeric(10,2)'),
      (3,'HammerHeadStyle','varchar(30)');
GO


CREATE TABLE Hardware.EquipmentProperty
(
    EquipmentId int NOT NULL
      CONSTRAINT 
           FKEquipment$hasExtendedPropertiesIn$HardwareEquipmentProperty
           REFERENCES Hardware.Equipment(EquipmentId),
    EquipmentPropertyTypeId int
      CONSTRAINT 
        FKEquipmentPropertyTypeId$definesTypesFor$HardwareEquipmentProperty
           REFERENCES Hardware.EquipmentPropertyType
                                      (EquipmentPropertyTypeId),
    Value sql_variant,
    CONSTRAINT PKEquipmentProperty PRIMARY KEY
                                  (EquipmentId, EquipmentPropertyTypeId)
);
GO

CREATE PROCEDURE Hardware.EquipmentProperty$Insert
(
    @EquipmentId int,
    @EquipmentPropertyName varchar(15),
    @Value sql_variant
)
AS
 BEGIN
    SET NOCOUNT ON;
    DECLARE @entryTrancount int = @@trancount;

    BEGIN TRY
        DECLARE @EquipmentPropertyTypeId int,
                @TreatAsDatatype sysname;

        SELECT @TreatAsDatatype = TreatAsDatatype,
               @EquipmentPropertyTypeId = EquipmentPropertyTypeId
        FROM   Hardware.EquipmentPropertyType
        WHERE  EquipmentPropertyType.Name = @EquipmentPropertyName;

      BEGIN TRANSACTION;
        --insert the value
        INSERT INTO Hardware.EquipmentProperty
                (EquipmentId, EquipmentPropertyTypeId, Value)
        VALUES (@EquipmentId, @EquipmentPropertyTypeId, @Value);

        --Then get that value from the table and cast it in a dynamic SQL
        -- call.  This will raise a trappable error if the type is 
        --incompatible
        DECLARE @validationQuery  varchar(max) =
           CONCAT(' DECLARE @value sql_variant
                   SELECT  @value = CAST(VALUE AS ', @TreatAsDatatype, ')
                   FROM    Hardware.EquipmentProperty
                   WHERE   EquipmentId = ', @EquipmentId, '
                     and   EquipmentPropertyTypeId = ' ,
                                  @EquipmentPropertyTypeId);

        EXECUTE (@validationQuery);
      COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
         IF @@TRANCOUNT > 0
             ROLLBACK TRANSACTION;

         DECLARE @ERRORmessage nvarchar(4000)
         SET @ERRORmessage = CONCAT('Error occurred in procedure ''',
                  OBJECT_NAME(@@procid), ''', Original Message: ''',
                  ERROR_MESSAGE(),''' Property:''',@EquipmentPropertyName,
                 ''' Value:''',cast(@Value as nvarchar(1000)),'''');
      THROW 50000,@ERRORMessage,1;
      RETURN -100;

     END CATCH;
  END;
GO

--causes error
--width is numeric(10,2)
EXEC Hardware.EquipmentProperty$Insert 1,'Width','Claw'; 
GO

EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Width', @Value = 2;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'Length',@Value = 8.4;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =1 ,
        @EquipmentPropertyName = 'HammerHeadStyle',@Value = 'Claw';
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Width',@Value = 1;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =2 ,
        @EquipmentPropertyName = 'Length',@Value = 7;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Width',@Value = 6;
EXEC Hardware.EquipmentProperty$Insert @EquipmentId =3 ,
        @EquipmentPropertyName = 'Length',@Value = 12.1;
GO

SELECT Equipment.EquipmentTag,Equipment.EquipmentType,
       EquipmentPropertyType.name, EquipmentProperty.Value
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                           EquipmentProperty.EquipmentPropertyTypeId;
GO

SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.
SELECT  Equipment.EquipmentTag,Equipment.EquipmentType,
   MAX(CASE WHEN EquipmentPropertyType.name = 'HammerHeadStyle' 
       THEN Value END) AS 'HammerHeadStyle',
   MAX(CASE WHEN EquipmentPropertyType.name = 'Length'
       THEN Value END) AS Length,
   MAX(CASE WHEN EquipmentPropertyType.name = 'Width' 
       THEN Value END) AS Width
FROM   Hardware.EquipmentProperty
         JOIN Hardware.Equipment
            on Equipment.EquipmentId = EquipmentProperty.EquipmentId
         JOIN Hardware.EquipmentPropertyType
            on EquipmentPropertyType.EquipmentPropertyTypeId =
                              EquipmentProperty.EquipmentPropertyTypeId
GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType;
SET ANSI_WARNINGS OFF; --eliminates the NULL warning on aggregates.
GO



SET ANSI_WARNINGS OFF;
DECLARE @query varchar(8000);
SELECT  @query = 'SELECT Equipment.EquipmentTag,Equipment.EquipmentType ' + (
                SELECT DISTINCT
                    ',MAX(CASE WHEN EquipmentPropertyType.name = ''' +
                       EquipmentPropertyType.name + ''' 
                       THEN CAST(Value AS ' +
                       EquipmentPropertyType.TreatAsDatatype + ') END) AS         
                       [' +
                       EquipmentPropertyType.name + ']' AS [text()]
                FROM
                    Hardware.EquipmentPropertyType
                FOR XML PATH('') , type ).value('.', 'NVARCHAR(MAX)') + '
                FROM  Hardware.EquipmentProperty
                       JOIN Hardware.Equipment
                          ON Equipment.EquipmentId =
                                     EquipmentProperty.EquipmentId
                       JOIN Hardware.EquipmentPropertyType
                          ON EquipmentPropertyType.EquipmentPropertyTypeId
                                = EquipmentProperty.EquipmentPropertyTypeId
          GROUP BY Equipment.EquipmentTag,Equipment.EquipmentType  '
EXEC (@query);
GO

----------------------------------------------------------------------------------------------------------
--Adding Columns To a Table
----------------------------------------------------------------------------------------------------------


ALTER TABLE Hardware.Equipment
    ADD Length numeric(10,2) SPARSE NULL;
GO

CREATE PROCEDURE Hardware.Equipment$AddProperty
(
    @propertyName   sysname, --the column to add
    @datatype       sysname, --the datatype as it appears in declaration
    @sparselyPopulatedFlag bit = 1 --Add column as sparse or not
)
WITH EXECUTE AS OWNER --provides the user the rights of the 
--owner of the object when executing this code
AS
 BEGIN

   --note: I did not include full error handling for clarity
   DECLARE @query nvarchar(max);

  --check for column existence
  IF NOT EXISTS (SELECT *
                FROM   sys.columns
                WHERE  name = @propertyName
                  AND  OBJECT_NAME(object_id) = 'Equipment'
                  AND  OBJECT_SCHEMA_NAME(object_id) = 'Hardware')
   BEGIN
      --build the ALTER statement, then execute it
      SET @query = 'ALTER TABLE Hardware.Equipment ADD ' 
                + quotename(@propertyName) + ' '
                + @datatype
                + case when @sparselyPopulatedFlag = 1 then ' SPARSE ' end
                + ' NULL ';
      EXEC (@query);
   END
  ELSE
      THROW 50000, 'The property you are adding already exists',1;
 END;
GO

--Previously Added
--EXEC Hardware.Equipment$AddProperty 'Length','numeric(10,2)',1; 
EXEC Hardware.Equipment$AddProperty 'Width','numeric(10,2)',1;
EXEC Hardware.Equipment$AddProperty 'HammerHeadStyle','varchar(30)',1;
GO

SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;
GO

UPDATE Hardware.Equipment
SET    Length = 7.00,
       Width =  1.00
WHERE  EquipmentTag = 'HANDSAW';
GO

SELECT EquipmentTag, EquipmentType, HammerHeadStyle,Length,Width
FROM   Hardware.Equipment;
GO

ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle IS NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');
GO

UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00,
       HammerHeadStyle = 'Wrong!'
WHERE  EquipmentTag = 'HANDSAW';
GO

UPDATE Hardware.Equipment
SET    Length = 12.10,
       Width =  6.00
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    Length = 8.40,
       Width =  2.00,
       HammerHeadStyle = 'Claw'
WHERE  EquipmentTag = 'CLAWHAMMER';

GO
SELECT EquipmentTag, EquipmentType, HammerHeadStyle ,Length,Width
FROM   Hardware.Equipment;
GO

SELECT name, is_sparse
FROM   sys.columns
WHERE  OBJECT_NAME(object_id) = 'Equipment'
GO


ALTER TABLE Hardware.Equipment
    DROP CONSTRAINT IF EXISTS CHKEquipment$HammerHeadStyle;
ALTER TABLE Hardware.Equipment
    DROP COLUMN IF EXISTS HammerHeadStyle, Length, Width;
GO


ALTER TABLE Hardware.Equipment
  ADD SparseColumns XML COLUMN_SET FOR ALL_SPARSE_COLUMNS;
GO

EXEC Hardware.Equipment$addProperty 'Length','numeric(10,2)',1;
EXEC Hardware.Equipment$addProperty 'Width','numeric(10,2)',1;
EXEC Hardware.Equipment$addProperty 'HammerHeadStyle','varchar(30)',1;
GO
ALTER TABLE Hardware.Equipment
 ADD CONSTRAINT CHKEquipment$HammerHeadStyle CHECK
        ((HammerHeadStyle is NULL AND EquipmentType <> 'Hammer')
        OR EquipmentType = 'Hammer');
GO

UPDATE Hardware.Equipment
SET    Length = 7,
       Width =  1
WHERE  EquipmentTag = 'HANDSAW';
GO

SELECT *
FROM   Hardware.Equipment;
GO

UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>12.10</Length><Width>6.00</Width>'
WHERE  EquipmentTag = 'POWERDRILL';

UPDATE Hardware.Equipment
SET    SparseColumns = '<Length>8.40</Length><Width>2.00</Width>
                        <HammerHeadStyle>Claw</HammerHeadStyle>'
WHERE  EquipmentTag = 'CLAWHAMMER';
GO

SELECT EquipmentTag, EquipmentType, HammerHeadStyle, Length, Width
FROM   Hardware.Equipment;
GO

SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE INDEX HammerHeadStyle_For_ClawHammer ON Hardware.Equipment (HammerHeadStyle) WHERE EquipmentType = 'Hammer';
GO


----------------------------------------------------------------------------------------------------------
--*****
--Storing Graph data in SQL Server
--*****
----------------------------------------------------------------------------------------------------------

CREATE SCHEMA Basics;
GO
CREATE TABLE Basics.Node1
(
	Node1Id int NOT NULL CONSTRAINT PKNode1 PRIMARY KEY
) 
AS NODE;
CREATE TABLE Basics.Node2
(
	Node2Id int NOT NULL CONSTRAINT PKNode2 PRIMARY KEY
) 
AS NODE;
GO


INSERT INTO Basics.Node1(Node1Id)
VALUES(1001),(1002);
INSERT INTO Basics.Node2(Node2Id)
VALUES(2011),(2012),(2020);
GO


SELECT *
FROM   Basics.Node1
WHERE  Node1.Node1Id = 1001;
GO


SELECT *
FROM   Basics.Node1
WHERE  $node_id = 
                '{"type":"node","schema":"Basics","table":"Node1","id":0}';
GO


CREATE TABLE Basics.Edge1
(
    ConnectedSinceTime datetime2(0) NOT NULL
	   CONSTRAINT DFLTEdge1_ConnectedSinceTime DEFAULT (SYSDATETIME()),
    CONSTRAINT EC_Edge1_Node1_to_Node2 
             CONNECTION (Basics.Node1 TO Basics.Node2) ON DELETE NO ACTION
)AS EDGE;
GO


CREATE OR ALTER PROCEDURE Basics.Edge1$Insert
(
	@From_Node1Id int,
	@To_Node2Id int,
	@OutputEdgeFlag bit = 0
) AS
 BEGIN
    --full procedure should have a TRY..CATCH and a THROW 

    --get the node_id values from the table to use in the insert
    DECLARE @from_node_id nvarchar(2000), @to_node_id nvarchar(2000)
    SELECT @from_node_id = $node_id
    FROM  Basics.Node1
    WHERE Node1.Node1Id = @From_Node1Id;

    SELECT @to_node_id = $node_id
    FROM  Basics.Node2
    WHERE Node2.Node2Id = @To_Node2Id;

    --insert the from and to nodes, let the ConnectedSinceTime default
    INSERT INTO Basics.Edge1($from_id, $to_id)
    VALUES(@from_node_id, @to_node_id);

    --show the edge that was created if desired	
    IF @OutputEdgeFlag = 1 
	   SELECT CONCAT('From:', $from_id, ' To:', $to_id, 
                 ' ConnectedSinceTime:', Edge1.ConnectedSinceTime)
	   FROM   Basics.Edge1
	   WHERE  $from_id = @from_node_id
	     AND  $to_id = @to_node_id

 END;
GO

EXEC Basics.Edge1$Insert @From_Node1Id = 1001, @To_Node2Id = 2011,                       
                         @OutputEdgeFlag = 1;
GO

EXEC Basics.Edge1$Insert @From_Node1Id = 1001, @To_Node2Id = 2012;
EXEC Basics.Edge1$Insert @From_Node1Id = 1002, @To_Node2Id = 2020; 
GO


SELECT Node1.Node1Id,  Node2.Node2Id
       --MATCH is not compatible with ANSI join syntax
FROM   Basics.Node1, Basics.Edge1, Basics.Node2
WHERE  MATCH(Node1-(Edge1)->Node2);
GO


ALTER TABLE Basics.Edge1
   ADD CONSTRAINT AKEdge1_UniqueNodes UNIQUE ($from_id, $to_id);
GO


----------------------------------------------------------------------------------------------------------
--Ascylic Graphs
----------------------------------------------------------------------------------------------------------

USE Chapter9;
GO
CREATE SCHEMA TreeInGraph;
GO

CREATE TABLE TreeInGraph.Company
(
    CompanyId int NOT NULL IDENTITY(1, 1) 
            CONSTRAINT PKCompany PRIMARY KEY,
    Name varchar(20) NOT NULL CONSTRAINT AKCompany_Name UNIQUE
) AS NODE;

CREATE TABLE TreeInGraph.CompanyEdge
(
	CONSTRAINT EC_CompanyEdge$DefinesParentOf 
	      CONNECTION (TreeInGraph.Company TO TreeInGraph.Company) 
		     ON DELETE NO ACTION,
      --enforces the one unique parent in the tree
	CONSTRAINT AKCompanyEdge_ToId UNIQUE ($to_id),
	--performance of fetching parent nodes
	INDEX FromIdToId ($from_id, $to_id)
)
AS EDGE;
GO


CREATE OR ALTER PROCEDURE TreeInGraph.Company$Insert
(
    @Name              varchar(20),
    @ParentCompanyName varchar(20)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; --will stop the operation if an error occurs
    BEGIN TRANSACTION;
    -- implement error handling if done for real

    --Get the node id of the paren
    DECLARE @ParentNode nvarchar(2000) = 
                   (SELECT $node_id 
                    FROM TreeInGraph.Company 
                    WHERE name = @ParentCompanyName);     

    IF @ParentCompanyName IS NOT NULL AND @ParentNode IS NULL
       THROW 50000, 'Invalid parentCompanyName', 1;
    ELSE
	BEGIN
         --insert done by simply using the Name of the parent to get 
         --the key of the parent...
         INSERT INTO TreeInGraph.Company(Name)
         SELECT @Name;
			
	  IF @ParentNode IS NOT NULL --then we need an edge inserted
           BEGIN
	      DECLARE @ChildNode nvarchar(1000) = 
                  (SELECT $node_id 
                   FROM TreeInGraph.Company 
                   WHERE name = @Name);

             INSERT INTO TreeInGraph.CompanyEdge ($from_id, $to_id) 
             VALUES (@ParentNode, @ChildNode);
	     END;
       END
     COMMIT TRANSACTION;
END;
GO

EXEC TreeInGraph.Company$Insert @Name = 'Company HQ', 
                                @ParentCompanyName = NULL;
EXEC TreeInGraph.Company$Insert @Name = 'Maine HQ', 
                                @ParentCompanyName = 'Company HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Tennessee HQ', 
                                @ParentCompanyName = 'Company HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Nashville Branch', 
                                @ParentCompanyName = 'Tennessee HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Knoxville Branch', 
                                @ParentCompanyName = 'Tennessee HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Memphis Branch', 
                                @ParentCompanyName = 'Tennessee HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Portland Branch', 
                                @ParentCompanyName = 'Maine HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Camden Branch', 
                                @ParentCompanyName = 'Maine HQ';
GO


DECLARE @CompanyId int = 1;

--First SELECT is to get the node that we are starting from as it 
--is not connected to itself, it would not be included in the SHORTEST_PATH 
--output.
SELECT  CompanyId AS ParentCompanyId,
        CompanyId AS CompanyId, Name, 
        1 AS TreeLevel, CAST(CompanyId AS varchar(10)) AS Hierarchy
FROM   TreeInGraph.Company
WHERE  Company.CompanyId = @CompanyId
UNION ALL
       --FromCompany is the root node in the set starting with @CompanyId
SELECT FromCompany.CompanyId AS ParentCompanyId,

       --Gives you the last value that is connected to the From node 
       --in the path of connections between the node
       LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) 
                                                         AS CompanyId,
	LAST_VALUE(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS Name,

       --Counting the nodes that were touched along the path gives you 
       --the level in the tree from the parameter node
	1+COUNT(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS TreeLevel,

       --the first CompanyId of the from company       
       CAST(FromCompany.CompanyId as NVARCHAR(10)) + 
        --Then STRING_AGG aggregates along the path, each company id
        '\' + STRING_AGG(CAST(ToCompany.CompanyId AS nvarchar(10)), '\')  
					WITHIN GROUP (GRAPH PATH) AS Hierarchy
FROM TreeInGraph.Company AS FromCompany,    
     --FOR PATH required in the declaration for nodes and edges that will
     --be used recursively     
     TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
     TreeInGraph.Company FOR PATH AS ToCompany

      --SHORTEST PATH starts with the anchor node, then the recursed nodes
      --in parenthesis. SHORTEST_PATH(Anchor(Matching Criteria)+)
      --+ indicates unlimited levels, replace with {0,1} to get 1 level
WHERE MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
  AND FromCompany.CompanyId = @CompanyId
ORDER BY Hierarchy;

-- Extra material

/* Proceudre to view the hierarchy: */

CREATE OR ALTER PROCEDURE TreeInGraph.Company$ViewHierarchy
(
	@StartingCompanyId int = NULL
) AS
BEGIN

IF @StartingCompanyId IS NULL 
	SET @StartingCompanyId = (SELECT CompanyId FROM TreeInGraph.Company
	                          WHERE $Node_id NOT IN (SELECT $to_id FROM TreeInGraph.CompanyEdge));

WITH Hieararchy AS (
	SELECT  CompanyId AS ParentCompanyId, CompanyId, Name, 1 AS TreeLevel, '1' AS Hierarchy
	FROM   TreeInGraph.Company
	UNION ALL
	SELECT 
			FromCompany.CompanyId AS ParentCompanyId,
			LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS CompanyId,
			LAST_VALUE(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS Name,
			1+COUNT(ToCompany.Name) WITHIN GROUP (GRAPH PATH) AS TreeLevel,
			CAST(FromCompany.CompanyId as NVARCHAR(10)) + 
			         '\' + STRING_AGG(cast(ToCompany.CompanyId as nvarchar(10)), '\')  
					  WITHIN GROUP (GRAPH PATH) AS Hierarchy
	FROM 
			TreeInGraph.Company AS FromCompany,         
			TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
			TreeInGraph.Company FOR PATH AS ToCompany
	WHERE 
			MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
)
SELECT CompanyId, Name, TreeLevel, Hierarchy
FROM   Hieararchy
WHERE  ParentCompanyId = @StartingCompanyId
ORDER BY Hierarchy
END;
GO

TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO

/*	Using a CTE to get children of a node, or see all paths, not just the shortest one: If you are not using SQL Server 2019 or later, or if you are implementing your tree using relational tables, SHORTEST_PATH will not be available. A recursive CTE is used to iterate through the levels in that case. This will be demonstrated.
*/

DECLARE @CompanyId int = 1;

--this is the MOST complex method of querying the Hierarchy, by far...
--algorithm is relational recursion

WITH CompanyHierarchy(CompanyId, ParentCompanyId, TreeLevel, Hierarchy)
AS (
   --gets the top level in Hierarchy we want. The Hierarchy column
   --will show the row's place in the Hierarchy from this query only
   --not in the overall reality of the row's place in the table
   SELECT Company.CompanyId,
          CAST(NULL AS int) AS CompanyId,
          1 AS TreeLevel,
          CAST(Company.CompanyId AS varchar(MAX)) + '\' AS Hierarchy
   FROM   TreeInGraph.Company

   WHERE  Company.CompanyId = @CompanyId

   
   UNION ALL

     --joins back to the CTE to recursively retrieve the rows 
     --note that TreeLevel is incremented on each iteration
     SELECT ToCompany.CompanyId, 
			FromCompany.CompanyId,
            TreeLevel + 1 as TreeLevel,
            Hierarchy + cast(ToCompany.CompanyId AS varchar(20)) + '\'  as Hierarchy
     FROM   CompanyHierarchy, TreeInGraph.Company	AS FromCompany,
			 --Cannot mix joins
			 --JOIN SocialGraph.Person	AS FromPerson
				--ON FromPerson.UserName = PersonHierarchy.UserName,
			TreeInGraph.CompanyEdge,TreeInGraph.Company	AS ToCompany
     WHERE  CompanyHierarchy.CompanyId = FromCompany.CompanyId
	   AND MATCH(FromCompany-(CompanyEdge)->ToCompany)
)
--return results from the CTE, joining to the Company data to get the 
--Company Name
SELECT   Company.CompanyId,
         Company.Name,
         CompanyHierarchy.TreeLevel,
         CompanyHierarchy.Hierarchy
FROM     TreeInGraph.Company
         INNER JOIN CompanyHierarchy
             ON Company.CompanyId = CompanyHierarchy.CompanyId
ORDER BY Hierarchy;
GO

/*	Reparent a Node: Moving the child of one node to be the child of another node. */

CREATE OR ALTER PROCEDURE TreeInGraph.Company$Reparent
(
    @Name                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	SET XACT_ABORT ON --simple way to stop tran on failure
	BEGIN TRANSACTION

	DECLARE @FromId nvarchar(1000),
			@ToId nvarchar(1000)

	SELECT @ToId = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @Name

	SELECT @FromId = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @NewParentCompanyName

	DELETE TreeInGraph.CompanyEdge
	WHERE  $to_id = @toId

	INSERT INTO TreeInGraph.CompanyEdge($From_id, $to_id)
	VALUES (@FromId, @ToId)

	COMMIT TRANSACTION;
END;
GO
EXEC TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO
EXEC TreeInGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO
EXEC TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO
EXEC TreeInGraph.Company$Reparent @Name = 'Maine HQ', @NewParentCompanyName = 'Company HQ';
GO
EXEC TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO


/*	Delete a Node: How to handle removing a node, especially a node that is not a leaf node. */

CREATE OR ALTER PROCEDURE TreeInGraph.Company$Delete
    @CompanyName         varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
	--simple error handling, stops process on error. Effective, but nearly as
	--descriptive as idea for real code
	SET XACT_ABORT ON

	DECLARE @CompanyId int;
	
	SELECT @CompanyId = CompanyId
	FROM   TreeinGraph.Company
	WHERE  name = @CompanyName

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
        BEGIN TRANSACTION
		
		--we are trusting the edge constraint to make sure that there     
        --are no orphaned rows, but we have to delete the row where 
		--this node is a child	

		DELETE FROM TreeInGraph.CompanyEdge
		WHERE  CompanyEdge.$to_id = (SELECT $node_id
		                             FROM   TreeInGraph.Company
									 WHERE  CompanyId = @CompanyId)

		DELETE TreeInGraph.Company
        WHERE  CompanyId = @CompanyId;

		COMMIT TRANSACTION

    END;
    ELSE
    BEGIN
        --deleting all of the child rows, get the nodes to delete, and then delete all edges and nodes 
		--of any child rows

		WITH Hieararchy AS (
			SELECT LAST_VALUE(ToCompany.$node_id) WITHIN GROUP (GRAPH PATH) AS CompanyNodeId
			FROM 
					TreeInGraph.Company AS FromCompany,         
					TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
					TreeInGraph.Company FOR PATH AS ToCompany
			WHERE 
					MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
			  AND   FromCompany.CompanyId = @CompanyId
		)
		SELECT CompanyNodeId
		INTO   #deleteThese
		FROM   Hieararchy

		INSERT INTO #deleteThese(CompanyNodeId)
		SELECT $node_id
		FROM   TreeinGraph.Company
		WHERE  CompanyId = @CompanyId

		BEGIN TRANSACTION

		DELETE TreeInGraph.CompanyEdge
        WHERE  $from_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.CompanyEdge
        WHERE  $to_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.Company
        WHERE $node_id IN (SELECT CompanyNodeId FROM #deleteThese)

		COMMIT TRANSACTION

    END;


END;
GO


/*
Not in book
*/
EXEC TreeInGraph.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';
EXEC TreeInGraph.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO

EXEC TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO

--try to delete Georgia
EXEC TreeInGraph.Company$Delete @CompanyName = 'Georgia HQ';
GO

/*
Msg 547, Level 16, State 0, Procedure TreeInGraph.Company$Delete, Line 24 [Batch Start Line 389]
The DELETE statement conflicted with the EDGE REFERENCE constraint "EC_CompanyEdge$DefinesParentOf". The conflict occurred in database "HierarchyExamples", table "TreeInGraph.CompanyEdge".
*/

--delete Atlanta
EXEC TreeInGraph.Company$Delete @CompanyName = 'Atlanta Branch';
GO 

EXEC TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO

EXEC TreeInGraph.Company$Delete @CompanyName = 'Georgia HQ', @DeleteChildRowsFlag = 1;

EXEC TreeInGraph.Company$ViewHierarchy


/* Not in book */

CREATE SEQUENCE TreeInGraph.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE TreeInGraph.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES TreeInGraph.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

CREATE PROCEDURE TreeInGraph.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO TreeInGraph.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   TreeInGraph.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Nashville Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Knoxville Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Memphis Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Portland Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Camden Branch';
GO


--Expanded Hierarchy
SELECT Company.CompanyId, Company.CompanyId
FROM   TreeInGraph.Company
UNION ALL
SELECT 
        FromCompany.CompanyId AS ParentCompanyId,
        LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS ChildCompanyId
FROM 
        TreeInGraph.Company AS FromCompany,         
        TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
        TreeInGraph.Company FOR PATH AS ToCompany
WHERE 
        MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))

GO

--take the expanded Hierarchy...
WITH ExpandedHierarchy AS
(
	SELECT Company.CompanyId AS ParentCompanyId, Company.CompanyId AS ChildCompanyId
	FROM   TreeInGraph.Company
	UNION ALL
	SELECT 
			FromCompany.CompanyId AS ParentCompanyId,
			LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS ChildCompanyId
	FROM 
			TreeInGraph.Company AS FromCompany,         
			TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
			TreeInGraph.Company FOR PATH AS ToCompany
	WHERE 
			MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
)
,
--get totals for each Company for the aggregate
CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   TreeInGraph.Sale
	GROUP BY CompanyId
),

--aggregate each Company for the Company
Aggregations AS (
SELECT ExpandedHierarchy.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
FROM   ExpandedHierarchy
			LEFT JOIN CompanyTotals
			ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
GROUP  BY ExpandedHierarchy.ParentCompanyId)

SELECT Company.Name, TotalSalesAmount
FROM   Aggregations
         JOIN TreeInGraph.Company
			ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY ParentCompanyId
go

-----------
-- Reparent a node

CREATE OR ALTER PROCEDURE TreeInGraph.Company$Reparent
(
    @CompanyName                 varchar(20),
    @NewParentCompanyName varchar(20)
)
AS
BEGIN
	SET XACT_ABORT ON --simple way to stop tran on failure
	     --important, because cant do this in on modification
		 --DML statement
	BEGIN TRANSACTION

	DECLARE @from_node_id nvarchar(1000),
			@to_node_id nvarchar(1000)
	
	--get the node_id we are moving
	SELECT @to_node_id = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @CompanyName

	--get the new location
	SELECT @from_node_id = $node_id
	FROM   TreeinGraph.Company
	WHERE  name = @NewParentCompanyName

    --delete the old edge, we can do this by the $to_node_id because
	--it is unique in single parent hierarchy
	DELETE TreeInGraph.CompanyEdge
	WHERE  $to_id = @to_node_id

	--insert the new edge
	INSERT INTO TreeInGraph.CompanyEdge($From_id, $to_id)
	VALUES (@from_node_id, @to_node_id)

	COMMIT TRANSACTION;
END;
GO

EXEC TreeInGraph.Company$Reparent @CompanyName = 'Maine HQ', @NewParentCompanyName = 'Tennessee HQ';
GO

TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1
GO
EXEC TreeInGraph.Company$Reparent @CompanyName = 'Maine HQ', @NewParentCompanyName = 'Company HQ';
GO
TreeInGraph.Company$ViewHierarchy @StartingCompanyId = 1

----------------------
-- Deleting a node

GO
CREATE OR ALTER PROCEDURE TreeInGraph.Company$Delete
    @CompanyName         varchar(20),
    @DeleteChildRowsFlag bit = 0
AS

BEGIN
	--simple error handling, stops process on error. Effective, but nearly as
	--descriptive as idea for real code
	SET XACT_ABORT ON

	DECLARE @CompanyId int;
	
	SELECT @CompanyId = CompanyId
	FROM   TreeinGraph.Company
	WHERE  name = @CompanyName

    IF @DeleteChildRowsFlag = 0 --don't delete children
    BEGIN
        BEGIN TRANSACTION
		
		--we are trusting the edge constraint to make sure that there     
        --are no orphaned rows, but we have to delete the row where 
		--this node is a child	

		DELETE FROM TreeInGraph.CompanyEdge
		WHERE  CompanyEdge.$to_id = (SELECT $node_id
		                             FROM   TreeInGraph.Company
									 WHERE  CompanyId = @CompanyId)

		DELETE TreeInGraph.Company
        WHERE  CompanyId = @CompanyId;

		COMMIT TRANSACTION

    END;
    ELSE
    BEGIN
        --deleting all of the child rows, get the nodes to delete, and then delete all edges and nodes 
		--of any child rows

		WITH Hieararchy AS (
			SELECT LAST_VALUE(ToCompany.$node_id) WITHIN GROUP (GRAPH PATH) AS CompanyNodeId
			FROM 
					TreeInGraph.Company AS FromCompany,         
					TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
					TreeInGraph.Company FOR PATH AS ToCompany
			WHERE 
					MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
			  AND   FromCompany.CompanyId = @CompanyId
		)
		SELECT CompanyNodeId
		INTO   #deleteThese
		FROM   Hieararchy

		INSERT INTO #deleteThese(CompanyNodeId)
		SELECT $node_id
		FROM   TreeinGraph.Company
		WHERE  CompanyId = @CompanyId

		BEGIN TRANSACTION

		DELETE TreeInGraph.CompanyEdge
        WHERE  $from_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.CompanyEdge
        WHERE  $to_id IN (SELECT CompanyNodeId FROM #deleteThese)
		  
		DELETE TreeInGraph.Company
        WHERE $node_id IN (SELECT CompanyNodeId FROM #deleteThese)

		COMMIT TRANSACTION

    END;


END;
GO


EXEC TreeInGraph.Company$Insert @Name = 'Georgia HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Atlanta Branch', @ParentCompanyName = 'Georgia HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Dalton Branch', @ParentCompanyName = 'Georgia HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Texas HQ', @ParentCompanyName = 'Company HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Dallas Branch', @ParentCompanyName = 'Texas HQ';

EXEC TreeInGraph.Company$Insert @Name = 'Houston Branch', @ParentCompanyName = 'Texas HQ';
GO

TreeInGraph.Company$ViewHierarchy 

--try to delete Georgia
EXEC TreeInGraph.Company$Delete @CompanyName = 'Georgia HQ';
GO

/*
Msg 547, Level 16, State 0, Procedure TreeInGraph.Company$Delete, Line 24 [Batch Start Line 389]
The DELETE statement conflicted with the EDGE REFERENCE constraint "EC_CompanyEdge$DefinesParentOf". The conflict occurred in database "HierarchyExamples", table "TreeInGraph.CompanyEdge".
*/

--delete Atlanta
EXEC TreeInGraph.Company$Delete @CompanyName = 'Atlanta Branch';
GO 

EXEC TreeInGraph.Company$ViewHierarchy

EXEC TreeInGraph.Company$Delete @CompanyName = 'Georgia HQ', @DeleteChildRowsFlag = 1;

EXEC TreeInGraph.Company$ViewHierarchy

EXEC TreeInGraph.Company$Delete @CompanyName = 'Texas HQ', @DeleteChildRowsFlag = 1;

EXEC TreeInGraph.Company$ViewHierarchy
GO

/* Aggregate over a Node: One of the main reasons to have a tree structure in a business database is to sum up activity of a node’s children. For example, the HQ node needs to sum up sales over the other nodes. Tennessee HQ needs to sum the sales of Nashville, Knoxville, and Memphis. */

--First create a table and some test sales data:

CREATE SEQUENCE TreeInGraph.CompanyDataGenerator_SEQUENCE
AS int
START WITH 1;
GO

CREATE TABLE TreeInGraph.Sale
(
    SalesId           int            NOT NULL IDENTITY(1, 1) CONSTRAINT PKSale PRIMARY KEY,
    TransactionNumber varchar(10)    NOT NULL CONSTRAINT AKSale UNIQUE,
    Amount            numeric(12, 2) NOT NULL,
    CompanyId         int            NOT NULL REFERENCES TreeInGraph.Company(CompanyId),
	INDEX XCompanyId (CompanyId, Amount)
);
GO

CREATE PROCEDURE TreeInGraph.Sale$InsertTestData
    @Name     varchar(20), --Note that all procs use natural keys to make it easier for you to work with manually.
                           --If you are implementing this for a tool to manipulate, use the surrogate keys
    @RowCount int = 5
AS
SET NOCOUNT ON;

WHILE @RowCount > 0
BEGIN
    INSERT INTO TreeInGraph.Sale(TransactionNumber, Amount, CompanyId)
    SELECT CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS varchar(10)),
           CAST(NEXT VALUE FOR TreeInGraph.CompanyDataGenerator_SEQUENCE AS numeric(12, 2)),
           (   SELECT Company.CompanyId
               FROM   TreeInGraph.Company
               WHERE  Company.Name = @Name);

    SET @RowCount = @RowCount - 1;
END;
GO

EXEC TreeInGraph.Sale$InsertTestData @Name = 'Nashville Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Knoxville Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Memphis Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Portland Branch';
EXEC TreeInGraph.Sale$InsertTestData @Name = 'Camden Branch';
GO

--Then get the expanded hieararchy, which is one row for every relationship between nodes. 

SELECT Company.CompanyId  AS ParentCompanyId, Company.CompanyId
FROM   TreeInGraph.Company
UNION ALL
SELECT 
        FromCompany.CompanyId AS ParentCompanyId,
        LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS ChildCompanyId
FROM 
        TreeInGraph.Company AS FromCompany,         
        TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
        TreeInGraph.Company FOR PATH AS ToCompany
WHERE 
        MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
ORDER BY ParentCompanyId, CompanyId
GO

/* You can see in the output of this query, that ParentCompanyId 1 has ever node in the tree as a CompanyId and itself, and each other node has a row for itself and all children

ParentCompanyId CompanyId
--------------- -----------
1               1
1               2
1               3
1               4
1               5
1               6
1               7
1               8
2               2
2               7
2               8
3               3
3               4
3               5
3               6
4               4
5               5
6               6
7               7
8               8


Use this to join to sales and sum the data
*/

--take the expanded Hierarchy...
WITH ExpandedHierarchy AS
(
	SELECT Company.CompanyId AS ParentCompanyId, Company.CompanyId AS ChildCompanyId
	FROM   TreeInGraph.Company
	UNION ALL
	SELECT 
			FromCompany.CompanyId AS ParentCompanyId,
			LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH) AS ChildCompanyId
	FROM 
			TreeInGraph.Company AS FromCompany,         
			TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
			TreeInGraph.Company FOR PATH AS ToCompany
	WHERE 
			MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
)
,
--get totals for each Company for the aggregate
CompanyTotals AS
(
	SELECT CompanyId, SUM(Amount) AS TotalAmount
	FROM   TreeInGraph.Sale
	GROUP BY CompanyId
),

--aggregate each Company for the Company
Aggregations AS (
SELECT ExpandedHierarchy.ParentCompanyId,SUM(CompanyTotals.TotalAmount) AS TotalSalesAmount
FROM   ExpandedHierarchy
			LEFT JOIN CompanyTotals
			ON CompanyTotals.CompanyId = ExpandedHierarchy.ChildCompanyId
GROUP  BY ExpandedHierarchy.ParentCompanyId)

SELECT Company.Name, TotalSalesAmount
FROM   Aggregations
         JOIN TreeInGraph.Company
			ON Company.CompanyId = Aggregations.ParentCompanyId
ORDER BY ParentCompanyId
go

--
--Kimball Helper Table
--
WITH BaseRows AS (
--Fetch every row as its own row
SELECT Company.CompanyId AS ParentCompanyId, 
       Company.CompanyId AS ChildCompanyId, 1 AS Distance,
	$node_id AS parent_node_id, $node_id AS child_node_id
FROM   TreeInGraph.Company
UNION ALL
--expand every row's child rows as rows in the output
SELECT FromCompany.CompanyId AS ParentCompanyId,
       LAST_VALUE(ToCompany.CompanyId) WITHIN GROUP (GRAPH PATH)  
                                                         AS ChildCompanyId,
       1+COUNT(ToCompany.NAME) WITHIN GROUP (GRAPH PATH) AS Distance,
	FromCompany.$node_id AS parent_node_id,
	LAST_VALUE(ToCompany.$node_id) WITHIN GROUP (GRAPH PATH) 
                                                         AS child_node_id
FROM 
		TreeInGraph.Company AS FromCompany,         
		TreeInGraph.CompanyEdge FOR PATH AS CompanyEdge,
		TreeInGraph.Company FOR PATH AS ToCompany
WHERE MATCH(SHORTEST_PATH(FromCompany(-(CompanyEdge)->ToCompany)+))
)

SELECT ParentCompanyId, ChildCompanyId, Distance, 
       --calculate parent and child nodes
       CASE WHEN NOT EXISTS (SELECT * FROM TreeInGraph.CompanyEdge 
	                      WHERE BaseRows.parent_node_id = $to_id) 
	THEN 1 ELSE 0 END AS ParentRootNodeFlag,
       CASE WHEN NOT EXISTS (SELECT * FROM TreeInGraph.CompanyEdge 
	                    WHERE BaseRows.parent_node_id = $from_id) 
	 THEN 1 ELSE 0 END AS ChildLeafNodeFlag
FROM BaseRows
ORDER BY ParentCompanyId, ChildCompanyId;
GO


----------------------------------------------------------------------------------------------------------
--*****
--Directed Acyclic Graph
--*****
----------------------------------------------------------------------------------------------------------
--Basic Table
CREATE SCHEMA DAG;
GO

CREATE TABLE DAG.Product
(
	ProductId	int NOT NULL IDENTITY 
	  CONSTRAINT PKProduct PRIMARY KEY,
	ProductName nvarchar(30) NOT NULL
	   CONSTRAINT AKProduct UNIQUE
) AS NODE;

CREATE TABLE DAG.BIllOfMaterial
(
  CONSTRAINT ECBillOfMaterial CONNECTION (DAG.Product TO DAG.Product) ON DELETE NO ACTION
)
AS EDGE
GO

--Procedure to insert nodes:

CREATE OR ALTER PROCEDURE DAG.BIllOfMaterial$Insert
(
    @ProductNameList         nvarchar(max),
    @IncludedInProductName   nvarchar(30)
)
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    --Sparse error handling for readability, implement error handling if done for real

	BEGIN TRANSACTION

	DECLARE @IncludedInProductNode nvarchar(1000) = (SELECT $node_id FROM DAG.Product 
	                                      WHERE ProductName = @IncludedInProductName);     

	INSERT INTO DAG.BIllOfMaterial ($from_id, $to_id) 
	SELECT @IncludedInProductNode,Product.$node_id
	FROM   DAG.Product
			 JOIN STRING_SPLIT(@ProductNameList,',') AS Names
				ON CAST(Names.value AS nvarchar(30)) = Product.ProductName

	COMMIT TRANSACTION

END;
GO

--Sample data:

INSERT INTO  DAG.Product ( ProductName)
VALUES  ('Wood Screw'),('Electrical Tape Roll'),
       ('Electrical Tape'),('Small Tape Spool'),
       ('Electrical Tape 5-pack'),('10 Wood Screw Pack'),
       ('100 ft Roll of Wire'),('Mounting Bracket'),
	   ('Small Screwdriver'),('Snurgle Mounting Kit'),
	   ('Electrical Tape 20-pack')

EXEC DAG.BIllOfMaterial$Insert @ProductNameList = 'Electrical Tape,Small Tape Spool',
							@IncludedInProductName = 'Electrical Tape Roll';
EXEC DAG.BIllOfMaterial$Insert @ProductNameList = 'Electrical Tape Roll',
							@IncludedInProductName = 'Electrical Tape 5-Pack';
EXEC DAG.BIllOfMaterial$Insert @ProductNameList = 'Electrical Tape Roll',
							@IncludedInProductName = 'Electrical Tape 20-Pack';
EXEC DAG.BIllOfMaterial$Insert @ProductNameList = 'Wood Screw',
							@IncludedInProductName = '10 Wood Screw Pack';
EXEC DAG.BIllOfMaterial$Insert 
     @ProductNameList = 'Electrical Tape Roll,10 Wood Screw Pack',
	@IncludedInProductName = 'Snurgle Mounting Kit';
EXEC DAG.BIllOfMaterial$Insert 
     @ProductNameList = '100 ft Roll of Wire, Mounting Bracket, Small Screwdriver',
	@IncludedInProductName = 'Snurgle Mounting Kit';

GO

CREATE PROCEDURE DAG.BIllOfMaterial$View
(
	@StartingProductNameLikeExpression nvarchar(30) = '%'
)
AS 

WITH Sorting AS (
SELECT 
        FromProduct.ProductName AS ProductName,
		STRING_AGG(ToProduct.ProductName,'\')  WITHIN GROUP (GRAPH PATH) AS IncludesParts
FROM 
        DAG.Product AS FromProduct,         
        DAG.BIllOfMaterial FOR PATH AS BIllOfMaterial,
        DAG.Product FOR PATH AS ToProduct
WHERE   MATCH(SHORTEST_PATH(FromProduct(-(BIllOfMaterial)->ToProduct)+))
  AND   FromProduct.ProductName LIKE @StartingProductNameLikeExpression
)
SELECT *
FROM   Sorting
ORDER BY ProductName, IncludesParts
GO

EXEC DAG.BIllOfMaterial$View
	@StartingProductNameLikeExpression = 'Snurgle Mounting kit'
GO

/*
ProductName                    IncludesParts
------------------------------ ----------------------------------------
Snurgle Mounting Kit           10 Wood Screw Pack
Snurgle Mounting Kit           10 Wood Screw Pack\Wood Screw
Snurgle Mounting Kit           100 ft Roll of Wire
Snurgle Mounting Kit           Electrical Tape Roll
Snurgle Mounting Kit           Electrical Tape Roll\Electrical Tape
Snurgle Mounting Kit           Electrical Tape Roll\Small Tape Spool
*/

EXEC DAG.BIllOfMaterial$View
	@StartingProductNameLikeExpression = 'Electrical Tape %-Pack'

/*
 ProductName                    IncludesParts
 ------------------------------ --------------------------------------------
 Electrical Tape 20-pack        Electrical Tape Roll
 Electrical Tape 20-pack        Electrical Tape Roll\Electrical Tape
 Electrical Tape 20-pack        Electrical Tape Roll\Small Tape Spool
 Electrical Tape 5-pack         Electrical Tape Roll
 Electrical Tape 5-pack         Electrical Tape Roll\Electrical Tape
 Electrical Tape 5-pack         Electrical Tape Roll\Small Tape Spool

*/ 


WITH Sorting AS (
SELECT 
        FromProduct.ProductName AS ProductName,
		STRING_AGG(ToProduct.ProductName,'\')  WITHIN GROUP (GRAPH PATH) AS IncludesParts
		,LAST_VALUE(ToProduct.ProductId) WITHIN GROUP (GRAPH PATH) ToProductId
FROM 
        DAG.Product AS FromProduct,         
        DAG.BIllOfMaterial FOR PATH AS BIllOfMaterial,
        DAG.Product FOR PATH AS ToProduct
WHERE   MATCH(SHORTEST_PATH(FromProduct(-(BIllOfMaterial)->ToProduct)+))
  
)
SELECT *
FROM   Sorting
ORDER BY ProductName, IncludesParts
GO

--Cause a cycle
DECLARE @from_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Wood Screw')
		, @to_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Snurgle Mounting Kit')


INSERT INTO DAG.BIllOfMaterial($from_id, $to_id)
VALUES (@from_id, @to_id)
GO

--show the cycle
WITH Sorting AS (
SELECT 
        FromProduct.ProductName AS ProductName,
		FromProduct.ProductId,
		STRING_AGG(ToProduct.ProductName,'\')  WITHIN GROUP (GRAPH PATH) AS IncludesParts
		,LAST_VALUE(ToProduct.ProductId) WITHIN GROUP (GRAPH PATH) ToProductId
FROM 
        DAG.Product AS FromProduct,         
        DAG.BIllOfMaterial FOR PATH AS BIllOfMaterial,
        DAG.Product FOR PATH AS ToProduct
WHERE   MATCH(SHORTEST_PATH(FromProduct(-(BIllOfMaterial)->ToProduct)+))
  
)
SELECT *
FROM   Sorting
WHERE  ProductId = ToProductId
GO

/*
You can see the cycle in this data now

ProductName                    ProductId   IncludesParts                                             
------------------------------ ----------- ----------------------------------------------------------
Wood Screw                     1           Snurgle Mounting Kit\10 Wood Screw Pack\Wood Screw        
10 Wood Screw Pack             6           Wood Screw\Snurgle Mounting Kit\10 Wood Screw Pack        
Snurgle Mounting Kit           10          10 Wood Screw Pack\Wood Screw\Snurgle Mounting Kit        
*/



--DELETE the bad row
--Cause a cycle
DECLARE @from_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Wood Screw')
		, @to_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Snurgle Mounting Kit')


DELETE FROM DAG.BIllOfMaterial
WHERE $from_id = @from_id
  AND $to_id = @to_id
GO

CREATE OR ALTER TRIGGER DAG.BillOfMaterial$InsertTrigger
ON DAG.BillOfMaterial
AFTER INSERT AS 
BEGIN
   DECLARE @msg varchar(2000),    --used to hold the error message
   --use inserted for insert or update trigger, deleted for 
   --update or delete trigger count instead of @@rowcount due to merge 
   --behavior that sets @@rowcount to a number that is equal to number of
   --merged rows, not rows being checked in trigger
           @rowsAffected int = (SELECT COUNT(*) FROM inserted);
           
   --no need to continue on if no rows affected
   IF @rowsAffected = 0 RETURN;

   SET NOCOUNT ON; --to avoid the rowcount messages
   SET ROWCOUNT 0; --in case the client has modified the rowcount

   BEGIN TRY
      --[validation section]
      --if this is an update, but they don’t change times or doctor, 
      --don’t check the data. UPDATE is always true for INSERT action
      BEGIN
			--this will search the entire graph... Will add filtering when able
			WITH Sorting AS (
			SELECT 
					FromProduct.ProductName AS ProductName,
					FromProduct.ProductId,
					STRING_AGG(ToProduct.ProductName,'\')  WITHIN GROUP (GRAPH PATH) AS IncludesParts
					,LAST_VALUE(ToProduct.ProductId) WITHIN GROUP (GRAPH PATH) ToProductId
			FROM 
					DAG.Product AS FromProduct,         
					DAG.BIllOfMaterial FOR PATH AS BIllOfMaterial,
					DAG.Product FOR PATH AS ToProduct
			WHERE   MATCH(SHORTEST_PATH(FromProduct(-(BIllOfMaterial)->ToProduct)+))
			)
			SELECT @msg = 'Cycles found after statement. One such path:' + ProductName + '\' + IncludesParts
			FROM   Sorting
			WHERE  ProductId = ToProductId      
			
			IF @msg IS NOT null
               BEGIN
                     IF @rowsAffected = 1
                        SELECT @msg = @msg
                     ELSE
                         SELECT @msg = 'One of the inserted rows caused an issue. ' + @msg;
                     THROW 50000,@msg,1;
               END;
         END;
          --[modification section]
   END TRY
   BEGIN CATCH
          IF @@trancount > 0
              ROLLBACK TRANSACTION;
          THROW;
     END CATCH;
END;
GO

--try to cause a cycle
DECLARE @from_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Wood Screw')
		, @to_id nvarchar(2000) = (SELECT $node_id
								   FROM   DAG.Product
								   WHERE  Product.ProductName = 'Snurgle Mounting Kit')


INSERT INTO DAG.BIllOfMaterial($from_id, $to_id)
VALUES (@from_id, @to_id)
GO

----------------------------------------------------------------------------------------------------------
--*****
--Cyclic Graphs
--*****
----------------------------------------------------------------------------------------------------------
CREATE SCHEMA SocialGraph;
GO

--table for accounts. Could have more attributes
CREATE TABLE SocialGraph.Account (
     AccountHandle nvarchar(30) CONSTRAINT AKAccount UNIQUE
) AS NODE;

--Holds the details of who follows whom
CREATE TABLE SocialGraph.Follows (
  FollowTime datetime2(0) NOT NULL
    CONSTRAINT DFLTFollows_FollowTime DEFAULT SYSDATETIME(),
    CONSTRAINT AKFollows_UniqueNodes UNIQUE ( $from_id, $to_id),
    CONSTRAINT ECFollows_AccountToAccount 
	 CONNECTION (SocialGraph.Account TO SocialGraph.Account) 
                                                    ON DELETE NO ACTION
) AS EDGE;
GO
--Cannot use $from_id and $to_id in a CHECK CONSTRAINT, so using 
--TRIGGER to avoid self reference
CREATE TRIGGER SocialGraph.Follows_IU_Trigger ON SocialGraph.Follows
AFTER INSERT, UPDATE
AS
BEGIN
    --for real object, use full template/error handling
    IF EXISTS (SELECT *
               FROM   inserted
               WHERE  $from_id = $to_id)
      BEGIN
        ROLLBACK;
        THROW 50000,'Modified data introduces a self reference',1;
      END;
END;
GO
--table of things an account could be interested in
CREATE TABLE SocialGraph.Interest (
    InterestName nvarchar(30) CONSTRAINT AKInterest UNIQUE
) AS NODE;

--edge to connect people to those interests
CREATE TABLE SocialGraph.InterestedIn 
(
	CONSTRAINT AKInterestedIn_UniqueNodes UNIQUE ($from_id, $to_id),
	CONSTRAINT ECInterestedIn_AccountToInterestBoth 
	     CONNECTION (SocialGraph.Account TO SocialGraph.Interest) 
                                                     ON DELETE NO ACTION
) AS EDGE;
GO

/* Not in book. Load the data: */

--this procedure is to simulate a user setting up an account
CREATE OR ALTER PROCEDURE SocialGraph.Account$Insert
(
    @AccountHandle			nvarchar(60),
    @InterestList			varchar(8000),
	@NonDirectionalLinkFlag bit = 0 --inserts both from and to for interest
	                                --relationship
)
AS
BEGIN
	--No error handling/transaction for simplicity of demo... 
	--You should have both when you do this for real

	--Insert the new row
    INSERT INTO SocialGraph.Account(AccountHandle)
    VALUES(@AccountHandle);

	--get the node id from the Account
	DECLARE @NodeId nvarchar(1000) 
	SET @NodeId = (SELECT $node_id FROM SocialGraph.Account WHERE AccountHandle = @AccountHandle)

	--create any new interests that don't currently exist
    INSERT INTO SocialGraph.Interest( InterestName)
    SELECT TRIM(value)
    FROM   STRING_SPLIT(@InterestList, ',') AS list
	WHERE  list.value <> ''
	  AND  list.value NOT IN (SELECT InterestName
						      FROM    SocialGraph.Interest)

	--create the interested in edges
	INSERT INTO SocialGraph.InterestedIn($from_id, $to_id)
	SELECT @NodeId,
			(SELECT $NODE_ID FROM SocialGraph.Interest WHERE Interest.InterestName = list.value)
	FROM   STRING_SPLIT(@InterestList, ',') AS list
	WHERE list.value <> ''

	IF @NonDirectionalLinkFlag = 1
	 BEGIN
		--create the interested in edges
        INSERT INTO SocialGraph.InterestedIn($from_id, $to_id)
        SELECT (SELECT $NODE_ID FROM SocialGraph.Interest WHERE Interest.InterestName = TRIM(list.value)),
			   @NodeId
        FROM   STRING_SPLIT(@InterestList, ',') AS list
        WHERE TRIM(list.value) <> ''

	 END


END
GO

--This is when a user is choosing who to follow later
CREATE OR ALTER PROCEDURE SocialGraph.Account$InsertFollowers
(
    @AccountHandle     nvarchar(60),
    @AccountHandleList varchar(8000) --limited to 8000 for demo, could be higher
)
AS
BEGIN
	--No error handling/transaction for simplicity of demo... 
	--You should have both when you do this for real

	--get the account's node_id value
	DECLARE @NodeId nvarchar(1000)
	SET @NodeId = (SELECT $NODE_ID FROM SocialGraph.Account WHERE AccountHandle = @AccountHandle)

	--insert accounts they follow
	INSERT INTO SocialGraph.Follows($from_id, $to_id)
	SELECT @NodeId,
			(SELECT $NODE_ID FROM SocialGraph.Account WHERE AccountHandle = TRIM(list.value))
	FROM   STRING_SPLIT(@AccountHandleList, ',') AS list
	WHERE  TRIM(list.value) <> ''

END;
GO

SELECT *
FROM   SocialGraph.Account
SELECT *
FROM   SocialGraph.Interest

SELECT *
FROM SocialGraph.Follows




EXEC SocialGraph.Account$Insert @AccountHandle = '@Joe',
     @InterestList = 'Bowling,Craziness,Dogs,Lodge Membership,Pickup Trucks';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Sam', 
     @InterestList = 'Bowling,Peace,Lodge Membership,Special Children';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Bertha', 
     @InterestList = 'Computers';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Betty', 
     @InterestList = 'Special Children';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Cameron', 
     @InterestList = 'Lodge Membership,Pickup Trucks';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Charles', 
     @InterestList = 'Lodge Membership,Bowling';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Merlin', 
     @InterestList = 'Craziness,Magic';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Lewis', 
     @InterestList = 'Bowling,Computers';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Cindy', 
     @InterestList = 'Computers';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Thomas', 
     @InterestList = 'Magic,Special Children';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Leonard', 
     @InterestList = 'Bowling';
EXEC SocialGraph.Account$Insert @AccountHandle = '@Fido', 
     @InterestList = 'Dogs,Bones';

GO
--shows that trigger works
PRINT 'This error is expected for the self reference'
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Joe', 
     @AccountHandleList = '@Joe';
GO

EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Joe', 
     @AccountHandleList = '@Bertha,@Betty,@Charles,@Fido';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Sam', 
     @AccountHandleList = '@Bertha,@Betty,@Joe';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Bertha', 
     @AccountHandleList = '@Sam,@Joe,@Betty,@Lewis';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Betty', 
     @AccountHandleList = '@Sam,@Bertha,@Joe';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Cameron', 
     @AccountHandleList = '@Joe';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Charles', 
     @AccountHandleList = '@Joe,@Sam';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Merlin', 
     @AccountHandleList = '@Joe,@Sam';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Fido', 
     @AccountHandleList = '@Joe';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Cindy', 
     @AccountHandleList = '@Joe,@Sam,@Thomas,@Fido';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Thomas', 
     @AccountHandleList = '@Sam,@Betty,@Cindy,@Lewis';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Leonard', 
     @AccountHandleList = '@Joe';
EXEC SocialGraph.Account$InsertFollowers @AccountHandle = '@Lewis', 
     @AccountHandleList = '@Cameron';

GO

-- what is @Joe interested in?
SELECT Account.AccountHandle, Interest.InterestName
FROM   SocialGraph.Account, SocialGraph.Interest, SocialGraph.InterestedIn
       --literally, what account is linked to interest through interestedIn
WHERE  MATCH(Account-(InterestedIn)->Interest)
  AND   Account.AccountHandle = '@Joe' --what @Joe is interested in
GO

--Who is @Joe connected to?
 SELECT FromAccount.AccountHandle AS FromAccountHandle, ToAccount.AccountHandle AS ToAccountHandle
FROM    SocialGraph.Account AS FromAccount, SocialGraph.Follows AS Follows,
		SocialGraph.Account AS ToAccount
WHERE  MATCH(FromAccount-(Follows)->ToAccount)
 AND   FromAccount.AccountHandle = '@Joe'
 ORDER BY FromAccountHandle, ToAccountHandle
GO

--Who shares an interest with @Joe, and what interests are they?
SELECT Account1.AccountHandle AS FromAccountHandle, 
       Account2.AccountHandle AS ToAccountHandle, 
       Interest.InterestName AS SharedInterestName
FROM   SocialGraph.Account AS Account1
	   ,SocialGraph.Account AS Account2
	   ,SocialGraph.Interest AS Interest
	   ,SocialGraph.InterestedIn
	   ,SocialGraph.InterestedIn AS InterestedIn2

	   --Account1 is interested in an interest, and Account2 is also
          --note the arrows show linkage, and we are navigating both
          --account nodes to the Interest node (you cannot reuse the 
          --the same edge in your queries)
WHERE  MATCH(Account1-(InterestedIn)->Interest<-(InterestedIn2)-Account2)
  AND  Account1.AccountHandle = '@Joe'	
     --ignore stuff you share with yourself
  AND  Account1.AccountHandle <> Account2.AccountHandle
ORDER BY FromAccountHandle, ToAccountHandle, SharedInterestName;
GO

--Who is @Joe connected who also shares a common interest?”
SELECT Account1.AccountHandle AS FromAccountHandle, Account2.AccountHandle AS ToAccountHandle, Interest.InterestName AS SharedInterestName
FROM   SocialGraph.Account AS Account1
	   ,SocialGraph.Account AS Account2
	   ,SocialGraph.Interest AS Interest
	   ,SocialGraph.InterestedIn
	   ,SocialGraph.InterestedIn AS InterestedIn2
	   ,SocialGraph.Follows
	 --Account1 is interested in an interest, and Account2 is also
WHERE  MATCH(Account1-(InterestedIn)->Interest<-(InterestedIn2)-Account2)
       --Account1 is connected to Account2
  AND  MATCH(Account1-(Follows)->Account2)
  AND  Account1.AccountHandle = '@Joe'
ORDER BY FromAccountHandle, ToAccountHandle, SharedInterestName;
GO


--Who is connected to @Joe, and who they are connected to
SELECT  Account1.AccountHandle AS FromAccountHandle, 
        ThroughAccount.AccountHandle AS ThroughAccountName, 
        Account2.AccountHandle AS ToAccountHandle
FROM    SocialGraph.Account AS Account1,
        SocialGraph.Follows AS Follows, 
        SocialGraph.Account AS Account2,
        SocialGraph.Follows AS Follows2, 
        SocialGraph.Account AS ThroughAccount
WHERE  MATCH(Account1-(Follows)->ThroughAccount-(Follows2)->Account2)
  AND  Account1.AccountHandle = '@Joe'
  AND  Account2.AccountHandle <> Account1.AccountHandle
ORDER BY FromAccountHandle, ToAccountHandle;
GO

--Who is @Joe connected to via follows, and how far away are they
SELECT	COUNT(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS Distance,
	LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) 
                                                            AS ConnectedTo,
	STRING_AGG(Account2.AccountHandle, '->') WITHIN GROUP (GRAPH PATH) 
                                                            AS Path
FROM   SocialGraph.Account AS Account1,
		SocialGraph.Follows FOR PATH AS Follows, 
		SocialGraph.Account  FOR PATH AS Account2
WHERE MATCH(SHORTEST_PATH(Account1(-(Follows)->Account2)+))
  AND Account1.AccountHandle = '@Joe';
GO


--How is @Joe connected to @Cindy through the shortest path 
--including interests
WITH BaseRows AS (
 SELECT  LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) 
                                               AS ConnectedToAccountHandle,
       Account1.AccountHandle + '->' + 
          STRING_AGG(CONCAT(Interest.InterestName,'->',
           Account2.AccountHandle), '->') WITHIN GROUP (GRAPH PATH) 
                                                          AS ConnectedPath
FROM   SocialGraph.Account AS Account1
	   ,SocialGraph.Account FOR PATH AS Account2
	   ,SocialGraph.Interest FOR PATH AS Interest
	   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn
	   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
	   
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn)->Interest<-
                                              (InterestedIn2)-Account2)+))
  AND  Account1.AccountHandle = '@Joe'
)
SELECT * 
FROM   BaseRows
WHERE  ConnectedToAccountHandle = '@Cindy';
GO


CREATE OR ALTER VIEW SocialGraph.AllNodes AS 
	SELECT Account.AccountHandle AS Display, 'Account' AS NodeType
	FROM   SocialGraph.Account
	UNION ALL
	SELECT Interest.InterestName AS Display, 'Interest' AS NodeType
	FROM   SocialGraph.Interest;
GO

CREATE OR ALTER VIEW SocialGraph.AllEdges AS 
	SELECT 'Follows' AS EdgeType
	FROM   SocialGraph.Follows
	UNION ALL
	SELECT 'InterestedIn' AS EdgeType
	FROM   SocialGraph.InterestedIn;
GO


SELECT AllNodes.Display,
       AllEdges.EdgeType,
       AllNodes2.Display
FROM   SocialGraph.AllNodes,
       SocialGraph.AllEdges,
       SocialGraph.AllNodes AS AllNodes2
WHERE  MATCH(AllNodes-(AllEdges)->AllNodes2)
  AND  AllNodes.Display = '@Joe';

GO

----------------------------------------------------------------------------------------------------------
--********************************************************************************************************
--Anti-Patterns
--********************************************************************************************************
----------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------
--*****
--Undecipherable Data
--*****
----------------------------------------------------------------------------------------------------------
CREATE SCHEMA Status;
GO
CREATE TABLE Status.StatusCode(
   StatusCodeId int NOT NULL CONSTRAINT PKStatusCode PRIMARY KEY,
   Name  varchar(20) NOT NULL CONSTRAINT AKStatusCode UNIQUE
);
INSERT INTO Status.StatusCode
VALUES (1,'Active'),(2,'Inactive'),(3,'BarelyActive'),
       (4,'DoNotUseAnyMore'),(5,'Asleep'),(6,'Dead');
GO

