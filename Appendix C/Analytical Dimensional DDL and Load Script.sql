-- Create separate database for this chapter
CREATE DATABASE [Chapter14];
GO

USE [Chapter14];
GO

-- Create schema for all dimension tables
CREATE SCHEMA dim;
GO

-- Create Date Dimension
CREATE TABLE dim.Date
(
        DateKey INTEGER NOT NULL,
        DateValue DATE NOT NULL,
        DayValue INTEGER NOT NULL,
        WeekValue INTEGER NOT NULL,
        MonthValue INTEGER NOT NULL,
        YearValue INTEGER NOT NULL
CONSTRAINT PK_Date PRIMARY KEY CLUSTERED 
(
        DateKey ASC
));
GO

-- Create Date Dimension Load Stored Procedure
CREATE PROCEDURE dim.LoadDate (@startDate DATETIME, @endDate DATETIME)
AS
BEGIN

IF NOT EXISTS (SELECT * FROM dim.Date WHERE DateKey = -1)
BEGIN
        INSERT INTO dim.Date
        SELECT -1, '01/01/1900', -1, -1, -1, -1;
END

WHILE @startdate <= @enddate
BEGIN
        IF NOT EXISTS (SELECT * FROM dim.Date WHERE DateValue = @startdate)
        BEGIN
                INSERT INTO dim.Date
                SELECT CONVERT(CHAR(8), @startdate, 112)        AS DateKey
                        ,@startdate                             AS DateValue
                        ,DAY(@startdate)                        AS DayValue
                        ,DATEPART(wk, @startdate)               AS WeekValue
                        ,MONTH(@startdate)                      AS MonthValue
                        ,YEAR(@startdate)                       AS YearValue
                SET @startdate = DATEADD(dd, 1, @startdate);
        END
END
END;
GO

--Execute the Data Dimension Load Stored Procedure
EXECUTE dim.LoadDate '01/01/2016', '12/31/2017';
GO

-- Create the Member dimension table
CREATE TABLE dim.Member
(
        MemberKey                       INTEGER NOT NULL IDENTITY(1,1),
        InsuranceNumber                 VARCHAR(12) NOT NULL,
        FirstName                       VARCHAR(50) NOT NULL,
        LastName                        VARCHAR(50) NOT NULL,
        PrimaryCarePhysician            VARCHAR(100) NOT NULL,
        County                          VARCHAR(40) NOT NULL,
        StateCode                       CHAR(2) NOT NULL,
        MembershipLength                VARCHAR(15) NOT NULL
CONSTRAINT PK_Member PRIMARY KEY CLUSTERED 
(
        MemberKey ASC
));
GO

-- Load Member dimension table
SET IDENTITY_INSERT [dim].[Member] ON;
GO
INSERT INTO [dim].[Member]
([MemberKey],[InsuranceNumber],[FirstName],[LastName],[PrimaryCarePhysician]
        ,[County],[StateCode],[MembershipLength])
SELECT -1, 'UNKNOWN','UNKNOWN','UNKNOWN','UNKNOWN','UNKNOWN','UN','UNKNOWN'
UNION ALL
SELECT 1, 'IN438973','Brandon','Jones','Dr. Keiser & Associates','Henrico','VA','<1 year'
UNION ALL
SELECT 2, 'IN958394','Nessa','Gomez','Healthy Lifestyles','Henrico','VA','1-2 year'
UNION ALL
SELECT 3, 'IN3867910','Catherine','Patten','Dr. Jenny Stevens','Spotsylvania','VA','<1 year';
GO
SET IDENTITY_INSERT [dim].[Member] OFF;
GO

ALTER TABLE dim.Member
ADD isCurrent INTEGER NOT NULL DEFAULT 1;
GO

INSERT INTO [dim].[Member]
([InsuranceNumber],[FirstName],[LastName],[PrimaryCarePhysician]
        ,[County],[StateCode],[MembershipLength])
VALUES
('IN438973','Brandon','Jones','Dr. Jenny Stevens','Henrico','VA','<1 year');
GO

UPDATE [dim].[Member] SET isCurrent = 0
WHERE InsuranceNumber = 'IN438973' AND PrimaryCarePhysician = 'Dr. Keiser & Associates';
GO

-- Create the Provider dimension table
CREATE TABLE dim.Provider (
        ProviderKey INTEGER IDENTITY(1,1) NOT NULL,
        NPI VARCHAR(10) NOT NULL,
        EntityTypeCode INTEGER NOT NULL,
        EntityTypeDesc VARCHAR(12) NOT NULL, -- (1:Individual,2:Organization)
        OrganizationName VARCHAR(70) NOT NULL,
        DoingBusinessAsName VARCHAR(70) NOT NULL,
        Street VARCHAR(55) NOT NULL,
        City VARCHAR(40) NOT NULL,
        State VARCHAR(40) NOT NULL,
        Zip VARCHAR(20) NOT NULL,
        Phone VARCHAR(20) NOT NULL,
        isCurrent INTEGER NOT NULL DEFAULT 1
 CONSTRAINT PK_Provider PRIMARY KEY CLUSTERED 
(
        ProviderKey ASC
));
GO

-- Insert sample data into Provider dimension table
SET IDENTITY_INSERT [dim].[Provider] ON;
GO
INSERT INTO [dim].[Provider]
([ProviderKey],[NPI],[EntityTypeCode],[EntityTypeDesc],[OrganizationName],
                [DoingBusinessAsName],[Street],[City],[State],[Zip],[Phone])
SELECT -1, 'UNKNOWN',-1,'UNKNOWN','UNKNOWN','UNKNOWN',
        'UNKNOWN','UNKNOWN','UNKNOWN','UNKNOWN','UNKNOWN'
UNION ALL
SELECT 1, '1234567',1,'Individual','Patrick Lyons','Patrick Lyons',
        '80 Park St.','Boston','Massachusetts','55555','555-123-1234'
UNION ALL
SELECT 2, '2345678',1,'Individual','Lianna White, LLC','Dr. White & Associates',
        '74 West Pine Ave.','Waltham','Massachusetts','55542','555-123-0012'
UNION ALL
SELECT 3, '76543210',2,'Organization','Doctors Conglomerate, Inc','Family Doctors',
        '25 Main Street Suite 108','Boston','Massachusetts','55555','555-321-4321'
UNION ALL
SELECT 4, '3456789',1,'Individual','Dr. Drew Adams','Dr. Drew Adams',
        '1207 Corporate Center','Peabody','Massachusetts','55554','555-234-1234';
SET IDENTITY_INSERT [dim].[Provider] OFF;
GO

-- Create the Benefit dimension table
CREATE TABLE dim.Benefit(
        BenefitKey INTEGER IDENTITY(1,1) NOT NULL,
        BenefitCode INTEGER NOT NULL,
        BenefitName VARCHAR(35) NOT NULL,
        BenefitSubtype VARCHAR(20) NOT NULL,
        BenefitType VARCHAR(20) NOT NULL
CONSTRAINT PK_Benefit PRIMARY KEY CLUSTERED 
(
        BenefitKey ASC
));
GO

-- Create the Health Plan dimension table
CREATE TABLE dim.HealthPlan(
        HealthPlanKey INTEGER IDENTITY(1,1) NOT NULL,
        HealthPlanIdentifier CHAR(4) NOT NULL,
        HealthPlanName VARCHAR(35) NOT NULL
CONSTRAINT PK_HealthPlan PRIMARY KEY CLUSTERED 
(
        HealthPlanKey ASC
));
GO

ALTER TABLE dim.Benefit
ADD HealthPlanKey INTEGER;
GO

ALTER TABLE dim.Benefit  WITH CHECK
ADD CONSTRAINT FK_Benefit_HealthPlan
FOREIGN KEY(HealthPlanKey) REFERENCES dim.HealthPlan (HealthPlanKey);
GO
-- Insert sample data into Health plan dimension
SET IDENTITY_INSERT [dim].[HealthPlan] ON;
GO
INSERT INTO [dim].[HealthPlan]
  ([HealthPlanKey], [HealthPlanIdentifier],[HealthPlanName])
SELECT 1, 'BRON','Bronze Plan'
UNION ALL
SELECT 2, 'SILV','Silver Plan'
UNION ALL
SELECT 3, 'GOLD','Gold Plan';
GO
SET IDENTITY_INSERT [dim].[HealthPlan] OFF;
GO

-- Create the AdjudicationType dimension table
CREATE TABLE dim.AdjudicationType (
        AdjudicationTypeKey INTEGER IDENTITY(1,1) NOT NULL,
        AdjudicationType VARCHAR(6) NOT NULL,
        AdjudicationCategory VARCHAR(8) NOT NULL
CONSTRAINT PK_AdjudicationType PRIMARY KEY CLUSTERED 
(
        AdjudicationTypeKey ASC
));
GO

-- Insert values for the AdjudicationType dimension
SET IDENTITY_INSERT dim.AdjudicationType ON;
GO
INSERT INTO dim.AdjudicationType
        (AdjudicationTypeKey, AdjudicationType, AdjudicationCategory)
SELECT -1, 'UNKNWN', 'UNKNOWN'
UNION ALL
SELECT 1, 'AUTO', 'ACCEPTED'
UNION ALL
SELECT 2, 'MANUAL', 'ACCEPTED'
UNION ALL
SELECT 3, 'AUTO', 'DENIED'
UNION ALL
SELECT 4, 'MANUAL', 'DENIED';
GO
SET IDENTITY_INSERT dim.AdjudicationType OFF;
GO


-- Create Diagnosis dimension table
CREATE TABLE dim.Diagnosis(
        DiagnosisKey int IDENTITY(1,1) NOT NULL,
        DiagnosisCode char(7) NULL,
        ShortDesc varchar(60) NULL,
        LongDesc varchar(350) NULL,
        OrderNumber int NULL,
 CONSTRAINT PK_Diagnosis PRIMARY KEY CLUSTERED 
(
        DiagnosisKey ASC
));
GO

-- Create HCPCSProcedure dimension table
CREATE TABLE dim.HCPCSProcedure (
        ProcedureKey INTEGER IDENTITY(1,1) NOT NULL,
        ProcedureCode CHAR(5) NOT NULL,
        ShortDesc VARCHAR(28) NOT NULL,
        LongDesc VARCHAR(80) NOT NULL
 CONSTRAINT PK_HCPCSProcedure PRIMARY KEY CLUSTERED 
(
        ProcedureKey ASC
));
GO

-- Create schema for all fact tables
CREATE SCHEMA fact;
GO

-- Create Claim Payment transaction fact table
CREATE TABLE fact.ClaimPayment
(
        DateKey INTEGER NOT NULL,
        MemberKey INTEGER NOT NULL,
        AdjudicationTypeKey INTEGER NOT NULL,
        ProviderKey INTEGER NOT NULL,
        DiagnosisKey INTEGER NOT NULL,
        ProcedureKey INTEGER NOT NULL,
        ClaimID VARCHAR(8) NOT NULL,
        ClaimAmount DECIMAL(10,2) NOT NULL,
        AutoPayoutAmount DECIMAL(10,2) NOT NULL,
        ManualPayoutAmount DECIMAL(10,2) NOT NULL,
        AutoAdjudicatedCount INTEGER NOT NULL,
        ManualAdjudicatedCount INTEGER NOT NULL,
        AcceptedCount INTEGER NOT NULL,
        DeniedCount INTEGER NOT NULL
);
GO

-- Add foreign keys from ClaimPayment fact to dimensions
ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_AdjudicationType
FOREIGN KEY(AdjudicationTypeKey) REFERENCES dim.AdjudicationType (AdjudicationTypeKey);
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Date
FOREIGN KEY(DateKey) REFERENCES dim.Date (DateKey);
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Diagnosis
FOREIGN KEY(DiagnosisKey) REFERENCES dim.Diagnosis (DiagnosisKey);
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_HCPCSProcedure
FOREIGN KEY(ProcedureKey) REFERENCES dim.HCPCSProcedure (ProcedureKey);
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Member
FOREIGN KEY(MemberKey) REFERENCES dim.Member (MemberKey);
GO

ALTER TABLE fact.ClaimPayment  WITH CHECK 
ADD CONSTRAINT FK_ClaimPayment_Provider
FOREIGN KEY(ProviderKey) REFERENCES dim.Provider (ProviderKey);
GO

-- Insert sample data into ClaimPayment fact table
DECLARE @i INT;
SET @i = 0;

WHILE @i < 1000
BEGIN
INSERT INTO fact.ClaimPayment
(
        DateKey, MemberKey, AdjudicationTypeKey, ProviderKey, DiagnosisKey,
        ProcedureKey, ClaimID, ClaimAmount, AutoPayoutAmount, ManualPayoutAmount,
        AutoAdjudicatedCount, ManualAdjudicatedCount, AcceptedCount, DeniedCount
)
SELECT 
        CONVERT(CHAR(8), DATEADD(dd, RAND() * -100, getdate()), 112),
        (SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.Member),
        (SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.AdjudicationType),
        (SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.Provider),
        (SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.Diagnosis),
        (SELECT CEILING((COUNT(*) - 1) * RAND()) from dim.HCPCSProcedure),
        'CL' + CAST(@i AS VARCHAR(6)),
        RAND() * 100000,
        RAND() * 100000 * (@i % 2),
        RAND() * 100000 * ((@i+1) % 2),
        0,
        0,
        0,
        0;
SET @i = @i + 1;
END;
GO
UPDATE fact.ClaimPayment
SET AutoAdjudicatedCount = CASE WHEN AdjudicationTypeKey IN (1,3) THEN 1 ELSE 0 END
	,ManualAdjudicatedCount = CASE WHEN AdjudicationTypeKey IN (2,4) THEN 1 ELSE 0 END
	,AcceptedCount = CASE WHEN AdjudicationTypeKey IN (1,2) THEN 1 ELSE 0 END
	,DeniedCount = CASE WHEN AdjudicationTypeKey IN (3,4) THEN 1 ELSE 0 END
FROM fact.ClaimPayment;
GO

-- Create Membership snapshot fact table
CREATE TABLE fact.Membership (
        DateKey INTEGER NOT NULL,
        HealthPlanKey INTEGER NOT NULL,
        MemberAmount INTEGER NOT NULL
);
GO

-- Add foreign keys from Membership fact to dimensions
ALTER TABLE fact.Membership  WITH CHECK 
ADD CONSTRAINT FK_Membership_Date
FOREIGN KEY(DateKey) REFERENCES dim.Date (DateKey);
GO

ALTER TABLE fact.Membership  WITH CHECK 
ADD CONSTRAINT FK_Membership_HealthPlan
FOREIGN KEY(HealthPlanKey) REFERENCES dim.HealthPlan (HealthPlanKey);
GO

-- Insert sample data into the Membership fact table
DECLARE @startdate DATE;
DECLARE @enddate DATE;
SET @startdate = '1/1/2016';
SET @enddate = '12/31/2016';

WHILE @startdate <= @enddate
BEGIN
                INSERT INTO fact.Membership
                SELECT CONVERT(CHAR(8), @startdate, 112)      AS DateKey
                                ,1 AS HPKey
                                ,RAND() * 1000 AS MemberAmount;
                INSERT INTO fact.Membership
                SELECT CONVERT(CHAR(8), @startdate, 112)      AS DateKey
                                ,2 AS HPKey
                                ,RAND() * 1000 AS MemberAmount;
                INSERT INTO fact.Membership
                SELECT CONVERT(CHAR(8), @startdate, 112)      AS DateKey
                                ,3 AS HPKey
                                ,RAND() * 1000 AS MemberAmount;

                SET @startdate = DATEADD(dd, 1, @startdate);
END;
GO
