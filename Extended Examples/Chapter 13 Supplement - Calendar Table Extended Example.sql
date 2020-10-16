----------------------------------------------
--Calendar table


DROP TABLE Tools.Calendar;
GO
CREATE TABLE Tools.Calendar
(
        DateValue date NOT NULL CONSTRAINT PKtools_calendar PRIMARY KEY,
        DayName varchar(10) NOT NULL,
        MonthName varchar(10) NOT NULL,
        Year varchar(60) NOT NULL,
        Day tinyint NOT NULL,
        DayOfTheYear smallint NOT NULL,
        Month smallint NOT NULL,
        Quarter tinyint NOT NULL,
	WeekendFlag bit NOT NULL,

        --start of fiscal year configurable in the load process, currently
        --only supports fiscal months that match the calendar months.
        FiscalYear smallint NOT NULL,
        FiscalMonth tinyint NULL,
        FiscalQuarter tinyint NOT NULL,

        --used to give relative positioning, such as the previous 10 months
        --which can be annoying due to month boundaries
        RelativeDayCount int NOT NULL,
        RelativeWeekCount int NOT NULL,
        RelativeMonthCount int NOT NULL
);
GO

;WITH dates (newDateValue) AS (
        SELECT DATEADD(day,I,'17530101') AS newDateValue
        FROM Tools.Number
)
INSERT Tools.Calendar
        (DateValue ,DayName
        ,MonthName ,Year ,Day
        ,DayOfTheYear ,Month ,Quarter
        ,WeekendFlag ,FiscalYear ,FiscalMonth
        ,FiscalQuarter ,RelativeDayCount,RelativeWeekCount
        ,RelativeMonthCount)
SELECT
        dates.newDateValue AS DateValue,
        DATENAME (dw,dates.newDateValue) AS DayName,
        DATENAME (mm,dates.newDateValue) AS MonthName,
        DATENAME (yy,dates.newDateValue) AS Year,
        DATEPART(day,dates.newDateValue) AS Day,
        DATEPART(dy,dates.newDateValue) AS DayOfTheYear,
        DATEPART(m,dates.newDateValue) AS Month,
        CASE
                WHEN MONTH( dates.newDateValue) <= 3 THEN 1
                WHEN MONTH( dates.newDateValue) <= 6 THEN 2
                When MONTH( dates.newDateValue) <= 9 THEN 3
        ELSE 4 END AS quarter,

        CASE WHEN DATENAME (dw,dates.newDateValue) IN ('Saturday','Sunday')
                THEN 1
                ELSE 0
        END AS weekendFlag,

        ------------------------------------------------
        --the next three blocks assume a fiscal year starting in July.
        --change if your fiscal periods are different
        ------------------------------------------------
        CASE
                WHEN MONTH(dates.newDateValue) <= 6
                THEN YEAR(dates.newDateValue)
                ELSE YEAR (dates.newDateValue) + 1
        END AS fiscalYear,

        CASE
                WHEN MONTH(dates.newDateValue) <= 6
                THEN MONTH(dates.newDateValue) + 6
                ELSE MONTH(dates.newDateValue) - 6
         END AS fiscalMonth,

        CASE
                WHEN MONTH(dates.newDateValue) <= 3 then 3
                WHEN MONTH(dates.newDateValue) <= 6 then 4
                WHEN MONTH(dates.newDateValue) <= 9 then 1
        ELSE 2 END AS fiscalQuarter,

        ------------------------------------------------
        --end of fiscal quarter = july
        ------------------------------------------------

        --these values can be anything, as long as they
        --provide contiguous values on year, month, and week boundaries
        DATEDIFF(day,'20000101',dates.newDateValue) AS RelativeDayCount,
        DATEDIFF(week,'20000101',dates.newDateValue) AS RelativeWeekCount,
        DATEDIFF(month,'20000101',dates.newDateValue) AS RelativeMonthCount

FROM    dates
WHERE  dates.newDateValue BETWEEN '20000101' AND '20200101'; --set the date range
GO

SELECT Calendar.FiscalYear, COUNT(*) AS OrderCount
FROM   /*WideWorldImporters.*/ Sales.Orders
         JOIN Tools.Calendar
               --note, the cast here could be a real performance killer
               --consider using a persisted calculated column here
            ON CAST(Orders.OrderDate as date) = Calendar.DateValue
WHERE    WeekendFlag = 1
GROUP BY Calendar.FiscalYear
ORDER BY Calendar.FiscalYear;
GO


DECLARE @interestingDate date = '20140509';

SELECT Calendar.DateValue as PreviousTwoWeeks, CurrentDate.DateValue AS Today,
        Calendar.RelativeWeekCount
FROM   Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) AS CurrentDate
              ON  Calendar.RelativeWeekCount < (CurrentDate.RelativeWeekCount)
                  and Calendar.RelativeWeekCount >=
                                         (CurrentDate.RelativeWeekCount -2);
GO

DECLARE @interestingDate date = '20140509'

SELECT MIN(Calendar.DateValue) AS MinDate, MAX(Calendar.DateValue) AS MaxDate
FROM   Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
              ON  Calendar.RelativeMonthCount < (CurrentDate.RelativeMonthCount)
                  AND Calendar.RelativeMonthCount >=
                                       (CurrentDate.RelativeMonthCount -12);
GO

DECLARE @interestingDate date = '20140509'

SELECT Calendar.Year, Calendar.Month, COUNT(*) AS OrderCount
FROM   /*WorldWideImporters.*/ Sales.Orders
         JOIN Tools.Calendar
           JOIN (SELECT *
                 FROM Tools.Calendar
                 WHERE DateValue = @interestingDate) as CurrentDate
                   ON  Calendar.RelativeMonthCount <=
                                           (CurrentDate.RelativeMonthCount )
                    AND Calendar.RelativeMonthCount >=
                                           (CurrentDate.RelativeMonthCount -10)
            ON Orders.ExpectedDeliveryDate = Calendar.DateValue
GROUP BY Calendar.Year, Calendar.Month	
ORDER BY Calendar.Year, Calendar.Month;
GO