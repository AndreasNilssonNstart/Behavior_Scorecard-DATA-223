

DECLARE 
    @ReportDate DATE = '2024-02-29',
    @CSDate DATE = '1900-01-01',
    @Store INT = 0,
    @FirstDayOfCurrentMonth DATE,  -- Declare without initializing
    @LastDayOfPreviousMonth DATE;  -- Declare without initializing

-- Now, apply your logic
IF @ReportDate = '1900-01-01'
BEGIN
    SELECT 
        @ReportDate = MAX(SnapshotDate),
        @CSDate = MAX(SnapshotDate) 
    FROM nystart.LoanPortfolioMonthly 
    WHERE IsMonthEnd = 1;
END;

-- After determining @ReportDate, calculate the first and last days as needed
SET @FirstDayOfCurrentMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, @ReportDate), 0);
SET @LastDayOfPreviousMonth = DATEADD(DAY, -1, @FirstDayOfCurrentMonth);

with thisthree as (

SELECT 


        ReportDate,
        AccountNumber,
        RiskStage, 
        SpecialCase,
        FBE,
base,
ECL_SUM,
ECLNPV_SUM

    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24] 

    WHERE Ord = 0  and ReportDate = @ReportDate  ) 

,
lasttwo as (

    select 
            ReportDate,
        AccountNumber,
        RiskStage, 
        SpecialCase,
        FBE,
base,
ECL_SUM,
ECLNPV_SUM


FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24] 

WHERE Ord = 0  and ReportDate = @LastDayOfPreviousMonth

),

new_entries as ( SELECT t.* from thisthree t where t.RiskStage = 'Stage3' and t.AccountNumber in (select AccountNumber from lasttwo  where RiskStage = 'Stage2')),

new_entries_sum as (
SELECT 

    
    COUNT(*) AS TotalEntries, -- Counts all rows in the table
    SUM(base) AS Balance, 
    SUM(ECL_SUM) AS ECL_SUM, 
    SUM(ECLNPV_SUM) AS ECLNPV_SUM
FROM new_entries
),

WO as ( SELECT t.* from lasttwo t where t.RiskStage = 'Stage3' and t.AccountNumber not in (select AccountNumber from thisthree))


SELECT 

FBE,
    COUNT(*) AS TotalEntries, -- Counts all rows in the table
    SUM(base) AS Balance, 
    SUM(ECL_SUM) AS ECL_SUM, 
    SUM(ECLNPV_SUM) AS ECLNPV_SUM
FROM WO

group by FBE
















DECLARE 
    @ReportDate DATE = '2024-02-29',
    @CSDate DATE = '1900-01-01',
    @Store INT = 0,
    @FirstDayOfCurrentMonth DATE,  -- Declare without initializing
    @LastDayOfPreviousMonth DATE;  -- Declare without initializing

-- Now, apply your logic
IF @ReportDate = '1900-01-01'
BEGIN
    SELECT 
        @ReportDate = MAX(SnapshotDate),
        @CSDate = MAX(SnapshotDate) 
    FROM nystart.LoanPortfolioMonthly 
    WHERE IsMonthEnd = 1;
END;

-- After determining @ReportDate, calculate the first and last days as needed
SET @FirstDayOfCurrentMonth = DATEADD(MONTH, DATEDIFF(MONTH, 0, @ReportDate), 0);
SET @LastDayOfPreviousMonth = DATEADD(DAY, -1, @FirstDayOfCurrentMonth);

-- Now you can proceed with your CTE and subsequent operations
;WITH stage AS (
    SELECT 
        ReportDate,
        RiskStage, 
        SUM(base) AS Balance, 
        SUM(ECL_SUM) AS ECL_SUM, 
        SUM(ECLNPV_SUM) AS ECLNPV_SUM 
    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24] 
    WHERE Ord = 0 AND ReportDate IN (@ReportDate, @LastDayOfPreviousMonth)
    GROUP BY ReportDate, RiskStage
)

SELECT * from stage
,
total AS (
    SELECT  
        'Total' AS RiskStage, 
        SUM(base) AS Balance, 
        SUM(ECL_SUM) AS ECL_SUM, 
        SUM(ECLNPV_SUM) AS ECLNPV_SUM
    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24] 
    WHERE Ord = 0 AND ReportDate IN (@ReportDate, @LastDayOfPreviousMonth)
)
-- Concatenate stage and total results
SELECT * FROM stage
UNION ALL
SELECT * FROM total;