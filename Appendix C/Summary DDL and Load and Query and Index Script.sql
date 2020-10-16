USE [Chapter14];
GO

-- Create schema for summary tables
CREATE SCHEMA [sum];
GO

-- Create Daily Claims table
CREATE TABLE [sum].DailyClaims (
        ClaimDate DATE NOT NULL,
        AdjudicationType VARCHAR(6) NOT NULL,
        ClaimCount INTEGER NOT NULL,
        ClaimAmount DECIMAL(10,2) NOT NULL
);
GO

-- Add sample data for summary tables
DECLARE @i INT;
SET @i = 0;

WHILE @i < 1000
BEGIN
INSERT INTO sum.DailyClaims
(
        ClaimDate, AdjudicationType, ClaimCount, ClaimAmount
)
SELECT 
        CONVERT(CHAR(8), DATEADD(dd, RAND() * -100, getdate()), 112),
        CASE CEILING(2 * RAND())
        WHEN 1 THEN 'AUTO'
        ELSE 'MANUAL'
        END,
        1,
        RAND() * 100000;
SET @i = @i + 1;
END;
GO

-- Create Monthly Claims table
CREATE TABLE [sum].MonthlyClaims (
        ClaimMonth INTEGER NOT NULL,
        ClaimYear INTEGER NOT NULL,
        AdjudicationType VARCHAR(6) NOT NULL,
        ClaimCount INTEGER NOT NULL,
        ClaimAmount DECIMAL(10,2) NOT NULL
);
GO

-- Create Yearly Claims table
CREATE TABLE [sum].YearlyClaims (
        ClaimYear INTEGER NOT NULL,
        AdjudicationType VARCHAR(6) NOT NULL,
        ClaimCount INTEGER NOT NULL,
        ClaimAmount DECIMAL(10,2) NOT NULL
);
GO

-- Insert summarized data
INSERT INTO sum.MonthlyClaims
SELECT MONTH(ClaimDate), YEAR(ClaimDate), AdjudicationType,
      SUM(ClaimCount), SUM(ClaimAmount)
FROM sum.DailyClaims
GROUP BY MONTH(ClaimDate), YEAR(ClaimDate), AdjudicationType;
GO

INSERT INTO sum.YearlyClaims
SELECT YEAR(ClaimDate), AdjudicationType, SUM(ClaimCount), SUM(ClaimAmount)
FROM sum.DailyClaims
GROUP BY YEAR(ClaimDate), AdjudicationType;
GO

-- Queries and Indexes
SELECT ClaimDate, AdjudicationType, ClaimCount, ClaimAmount
FROM sum.DailyClaims;

SELECT ClaimMonth, ClaimYear, AdjudicationType, ClaimCount, ClaimAmount
FROM sum.MonthlyClaims;

SELECT ClaimYear, AdjudicationType, ClaimCount, ClaimAmount
FROM sum.YearlyClaims;

SELECT ClaimDate, AdjudicationType, ClaimCount, ClaimAmount
FROM sum.DailyClaims
WHERE ClaimDate BETWEEN DATEADD(MONTH, -3, getdate()) and getdate()
ORDER BY ClaimDate;

SELECT ClaimMonth, ClaimYear, [AUTO], [MANUAL]
FROM
(SELECT ClaimMonth, ClaimYear, AdjudicationType, ClaimAmount 
    FROM sum.MonthlyClaims) AS Claims
PIVOT
(
SUM(ClaimAmount)
FOR AdjudicationType IN ([AUTO], [MANUAL])
) AS PivotedClaims;

SELECT SUM(ClaimCount)
FROM sum.DailyClaims
WHERE ClaimDate = '07/10/2016';

CREATE NONCLUSTERED INDEX NonClusteredIndex ON sum.DailyClaims
(
        ClaimDate ASC,
        ClaimCount
);
GO
