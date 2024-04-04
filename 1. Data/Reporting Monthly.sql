



--SELECT top(100)* FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]

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

with this as (   SELECT * FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]  WHERE Ord = 0  and ReportDate = @ReportDate  ) 

,
last as ( select  *   FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]  WHERE Ord = 0  and ReportDate = @LastDayOfPreviousMonth),

new_entries as ( SELECT t.* from this t where t.RiskStage = 'Stage3' and t.AccountNumber in (select AccountNumber from last  where RiskStage in ('Stage1','Stage2') ))


SELECT l.AccountNumber , l.Base as Last_Base, t.Base as this_Base , l.ECLNPV_SUM  ,t.ECLNPV_SUM as This_ECLNPV_SUM,l.RiskStage ,t.RiskStage as This_RiskStage , l.SpecialCase , t.SpecialCase as This_SpecialCase

, case when l.RiskStage  = 'Stage3' and t.RiskStage is null then 'WO_Out' 
       when t.RiskStage  = 'Stage2' and l.RiskStage = 'Stage3' then 'Cure_S2'                -- bort med denna och betalplan och eftergift istället
       when l.RiskStage  = 'Stage2' and t.RiskStage = 'Stage3' then 'New_Entries_S3'
        when l.RiskStage  = 'Stage1' and t.RiskStage = 'Stage2' then 'New_Entries_S2'
        when l.RiskStage  = 'Stage2' and t.RiskStage = 'Stage1' then 'Cure_S1'
        when t.RiskStage  = 'Stage2' and t.FBE = 1 then 'FBE'                                -- bort med denna och betalplan och eftergift istället
    
         end as Walk

from last l 
full join this as t on l.AccountNumber = t.AccountNumber


order by t.ECLNPV_SUM







new_entries_sum as (
SELECT 

    
    COUNT(*) AS TotalEntries, -- Counts all rows in the table
    SUM(base) AS Balance, 
    SUM(ECL_SUM) AS ECL_SUM, 
    SUM(ECLNPV_SUM) AS ECLNPV_SUM
FROM new_entries
)

--SELECT * from new_entries_sum

,

WO as ( SELECT t.* from lasttwo t where t.RiskStage = 'Stage3' and t.ECL_SUM > 0 and t.AccountNumber not in (select AccountNumber from thisthree where RiskStage <> 'Stage3'))

SELECT * from WO







SELECT 

FBE,
    COUNT(*) AS TotalEntries, -- Counts all rows in the table
    SUM(base) AS Balance, 
    SUM(ECL_SUM) AS ECL_SUM, 
    SUM(ECLNPV_SUM) AS ECLNPV_SUM
FROM WO

group by FBE











SELECT * 
FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]  where AccountNumber = 7840820 and ReportDate = '2024-02-29' and Ord = 0 and RiskStage <> 'Stage3'
















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
),
total AS (
    SELECT  
    ReportDate,
        'Total' AS RiskStage, 
        SUM(base) AS Balance, 
        SUM(ECL_SUM) AS ECL_SUM, 
        SUM(ECLNPV_SUM) AS ECLNPV_SUM
    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24] 
    WHERE Ord = 0 AND ReportDate IN (@ReportDate, @LastDayOfPreviousMonth)
    GROUP BY ReportDate
)




-- Concatenate stage and total results
SELECT * FROM stage
UNION ALL
SELECT * FROM total;
