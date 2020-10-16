USE [Chapter14];
GO

-- Create In-memory OLTP tables
CREATE TABLE [dbo].[AdjudicationType](
	[AdjudicationTypeID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY NONCLUSTERED,
	[AdjudicationType] [varchar](50) NOT NULL,
	[ModifiedDate] [datetime] NOT NULL
) WITH  
        (MEMORY_OPTIMIZED = ON,  
        DURABILITY = SCHEMA_AND_DATA);
GO

CREATE TABLE [dbo].[Member](
	[MemberID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY NONCLUSTERED,
	[CardNumber] [varchar](10) NOT NULL,
	[FirstName] [varchar](50) NOT NULL,
	[MiddleName] [varchar](50) NULL,
	[LastName] [varchar](50) NOT NULL,
	[Suffix] [varchar](10) NULL,
	[EmailAddress] [varchar](40) NULL,
	[ModifiedDate] [datetime] NOT NULL
) WITH  
        (MEMORY_OPTIMIZED = ON,  
        DURABILITY = SCHEMA_AND_DATA);
GO

CREATE TABLE [dbo].[Claim](
	[ClaimID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY NONCLUSTERED,
	[ReceivedDate] [datetime] NOT NULL,
	[DecisionDate] [datetime] NOT NULL,
	[MemberID] [int] NULL,
	[AdjudicationTypeID] [int] NOT NULL,
	[ClaimPayment] [money] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL
) WITH  
        (MEMORY_OPTIMIZED = ON,  
        DURABILITY = SCHEMA_AND_DATA);
GO

ALTER TABLE [dbo].[Claim]  WITH CHECK
ADD  CONSTRAINT [FK_dboClaim_AdjudicationType] FOREIGN KEY([AdjudicationTypeID])
REFERENCES [dbo].[AdjudicationType] ([AdjudicationTypeID]);
GO

ALTER TABLE [dbo].[Claim] CHECK CONSTRAINT [FK_dboClaim_AdjudicationType];
GO

ALTER TABLE [dbo].[Claim]  WITH CHECK
ADD  CONSTRAINT [FK_dboClaim_Member] FOREIGN KEY([MemberID])
REFERENCES [dbo].[Member] ([MemberID]);
GO

ALTER TABLE [dbo].[Claim] CHECK CONSTRAINT [FK_dboClaim_Member];
GO

-- Load AdjudicationType Table
INSERT INTO AdjudicationType VALUES ('AUTO', getdate());
GO

INSERT INTO AdjudicationType VALUES ('MANUAL', getdate());
GO


-- Load Member Table
INSERT INTO [dbo].[Member] ([CardNumber], [FirstName], [MiddleName],
		[LastName], [Suffix], [EmailAddress], [ModifiedDate])
VALUES ('ANT48963', 'Jessica', 'Diane', 'Moss', 'Ms.', 'jessica@email.com', getdate());
GO

INSERT INTO [dbo].[Member] ([CardNumber], [FirstName], [MiddleName],
		[LastName], [Suffix], [EmailAddress], [ModifiedDate])
VALUES ('ANT8723', 'Richard', 'John', 'Smith', 'Mr.', 'richard@email.com', getdate());
GO

INSERT INTO [dbo].[Member] ([CardNumber], [FirstName], [MiddleName],
		[LastName], [Suffix], [EmailAddress], [ModifiedDate])
VALUES ('BCBS8723', 'Paulette', 'Lara', 'Jones', 'Mrs.', 'paulette@email.com', getdate());
GO

-- Load Claim Table
DECLARE @i AS INT;
SET @i = 0;

WHILE @i < 250000
BEGIN
INSERT INTO [dbo].[Claim] ([ReceivedDate], [DecisionDate], [MemberID]
           ,[AdjudicationTypeID], [ClaimPayment], [ModifiedDate])
VALUES (DATEADD(day, cast((rand()*100) as int) % 28 + 1
        , DATEADD(month, cast((rand()*100) as int) % 12 + 1, '2016-01-01'))
	, DATEADD(day, cast((rand()*100) as int) % 28 + 1
        , DATEADD(month, cast((rand()*100) as int) % 12 + 1, '2016-01-01'))
	, cast((rand()*100) as int) % 3 + 1
	, cast((rand()*100) as int) % 2 + 1
	, cast((rand()*1000) as decimal(5, 2))
	, getdate())
SET @i = @i + 1
END;
GO

-- Queries and Indexes
SELECT count(m.CardNumber) AS ClaimCount
FROM dbo.Claim AS c
LEFT JOIN dbo.AdjudicationType AS adj ON c.AdjudicationTypeID = adj.AdjudicationTypeID
LEFT JOIN dbo.Member AS m ON c.MemberID = m.MemberID
WHERE AdjudicationType = 'MANUAL';

SELECT AdjudicationType, SUM(ClaimPayment) AS TotalAmt
FROM dbo.Claim AS c
LEFT JOIN dbo.AdjudicationType AS adj ON c.AdjudicationTypeID = adj.AdjudicationTypeID
LEFT JOIN dbo.Member AS m on c.MemberID = m.MemberID
WHERE DecisionDate > DATEADD(year, -1, getdate())
GROUP BY AdjudicationType;

-- Create Columnstore Tables
CREATE TABLE [dbo].[Claim_Columnstore]
(
	[ClaimID] [int] IDENTITY(1,1) NOT NULL,
	[ReceivedDate] [datetime] NOT NULL,
	[DecisionDate] [datetime] NOT NULL,
	[MemberID] [int] NULL,
	[AdjudicationTypeID] [int] NOT NULL,
	[ClaimPayment] [money] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
 PRIMARY KEY NONCLUSTERED 
(
	[ClaimID] ASC
),
INDEX IX_COLUMNSTORE CLUSTERED COLUMNSTORE  
) WITH ( MEMORY_OPTIMIZED = ON , DURABILITY = SCHEMA_AND_DATA );

GO

ALTER TABLE [dbo].[Claim_Columnstore]  WITH CHECK
ADD  CONSTRAINT [FK_dboClaimColumnstore_AdjudicationType]
FOREIGN KEY([AdjudicationTypeID])
REFERENCES [dbo].[AdjudicationType] ([AdjudicationTypeID]);
GO

ALTER TABLE [dbo].[Claim_Columnstore]
CHECK CONSTRAINT [FK_dboClaimColumnstore_AdjudicationType];
GO

ALTER TABLE [dbo].[Claim_Columnstore]  WITH CHECK
ADD  CONSTRAINT [FK_dboClaimColumnstore_Member]
FOREIGN KEY([MemberID])
REFERENCES [dbo].[Member] ([MemberID]);
GO

ALTER TABLE [dbo].[Claim_Columnstore]
CHECK CONSTRAINT [FK_dboClaimColumnstore_Member];
GO

-- Use Columnstore tables
SELECT count(m.CardNumber) AS ClaimCount
FROM dbo.Claim_Columnstore AS c
LEFT JOIN dbo.AdjudicationType AS adj ON c.AdjudicationTypeID = adj.AdjudicationTypeID
LEFT JOIN dbo.Member AS m ON c.MemberID = m.MemberID
WHERE AdjudicationType = 'MANUAL';

SELECT AdjudicationType, SUM(ClaimPayment) AS TotalAmt
FROM dbo.Claim_Columnstore AS c
LEFT JOIN dbo.AdjudicationType AS adj ON c.AdjudicationTypeID = adj.AdjudicationTypeID
LEFT JOIN dbo.Member AS m on c.MemberID = m.MemberID
WHERE DecisionDate > DATEADD(year, -1, getdate())
GROUP BY AdjudicationType;
