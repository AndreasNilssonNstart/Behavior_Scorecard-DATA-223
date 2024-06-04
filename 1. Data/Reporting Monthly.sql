


SELECT * from nystart.AcquisitionCostPOCI_24 where Ord = 0 and ReportDate ='2024-02-29'





SELECT * 

 from nystart.ECLInput






SELECT Stageing, avg(AdjustedBehaviourScore)

 from nystart.ECLInput

 where  AccountStatus = 'OPEN'

 group by Stageing  , SnapshotDate


SELECT  avg(Score) as S

 from nystart.ECLInput

where AccountStatus = 'OPEN'



SELECT 
Stageing, avg(Score)

 from nystart.ECLInput

where AccountStatus = 'OPEN'
  group by Stageing  , SnapshotDate


SELECT 
Stageing, avg(Score)

 from nystart.ECLInput

where AccountStatus = 'OPEN' <> Stage
  group by Stageing  , SnapshotDate






DECLARE 
    @ReportDate DATE = '1900-01-01',
    @CSDate DATE = '1900-01-01',
    @FirstDayOfCurrentMonth DATE,  -- Declare without initializing
    @LastDayOfPreviousMonth DATE,  -- Declare without initializing

    @Store INT = 0
    
    IF @ReportDate='1900-01-01'
	BEGIN
		SELECT @ReportDate=max(SnapshotDate),@CSDate=max(SnapshotDate) 
		from nystart.LoanPortfolioMonthly where IsMonthEnd=1
	END

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
       when l.RiskStage  = 'Stage2' and t.RiskStage = 'Stage3' then 'New_Entries_S3'
     
        when l.RiskStage  = 'Stage2' and t.RiskStage = 'Stage1' then 'Cure_S1'

        when l.RiskStage  = 'Stage1' and t.RiskStage = 'Stage2' then 'New_Entries_S2_SICR'
        when t.RiskStage  = 'Stage2' and t.FBE = 'monitoring_paymentrelief' then 'monitoring_paymentrelief'
        when t.RiskStage  = 'Stage2' and t.FBE = 'monitoring_previous_S3' then 'monitoring_previous_S3'                          
        when t.RiskStage  = 'Stage2'  then 'SICR'
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


DECLARE 
    @ReportDate DATE = '1900-01-01',
    @CSDate DATE = '1900-01-01',
    @FirstDayOfCurrentMonth DATE,
    @LastDayOfPreviousMonth DATE,
    @Store INT = 0;

    
-- Only set report dates if they are at their initial value
IF @ReportDate = '1900-01-01'
BEGIN
    -- Calculate the first day of the current month
    SET @FirstDayOfCurrentMonth = CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0) AS DATE);
    -- Calculate the last day of the previous month
    SET @LastDayOfPreviousMonth = DATEADD(DAY, -1, @FirstDayOfCurrentMonth);

    -- Set the ReportDate and CSDate to the last day of the previous month
    SET @ReportDate = @LastDayOfPreviousMonth;
    SET @CSDate = @LastDayOfPreviousMonth;
END;

-- CTE for data as of the report date
WITH this AS (
    SELECT * 
    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]
    WHERE Ord = 0 AND ReportDate = @ReportDate
),
-- CTE for data from the last day of the previous month
last AS (
    SELECT * 
    FROM [reporting-db].[nystart].[AcquisitionCostPOCI_24]
    WHERE Ord = 0 AND ReportDate = @LastDayOfPreviousMonth
),
-- CTE for new entries in Stage 3
new_entries AS (
    SELECT t.*
    FROM this t 
    WHERE t.RiskStage = 'Stage3' 
    AND t.AccountNumber IN (SELECT AccountNumber FROM last WHERE RiskStage IN ('Stage1', 'Stage2'))
)

-- Final SELECT with transition logic
SELECT 
    l.AccountNumber, 
    l.Base AS Last_Base, t.Base AS This_Base, 
    l.ECLNPV_SUM, t.ECLNPV_SUM AS This_ECLNPV_SUM,
    l.RiskStage, t.RiskStage AS This_RiskStage, 
    l.SpecialCase, t.SpecialCase AS This_SpecialCase,
    CASE 
        WHEN l.RiskStage = 'Stage3' AND t.RiskStage IS NULL THEN 'WO_Out' 
        WHEN l.RiskStage = 'Stage2' AND t.RiskStage = 'Stage3' THEN 'New_Entries_S3'
        WHEN l.RiskStage = 'Stage2' AND t.RiskStage = 'Stage1' THEN 'Cure_S1'
        WHEN l.RiskStage = 'Stage1' AND t.RiskStage = 'Stage2' THEN 'New_Entries_S2_SICR'
        WHEN t.RiskStage = 'Stage2' AND t.FBE = 'monitoring_paymentrelief' THEN 'monitoring_paymentrelief'
        WHEN t.RiskStage = 'Stage2' AND t.FBE = 'monitoring_previous_S3' THEN 'monitoring_previous_S3'                          
        WHEN t.RiskStage = 'Stage2' THEN 'SICR'
    END AS Walk
FROM last l 
FULL JOIN this t ON l.AccountNumber = t.AccountNumber
ORDER BY t.ECLNPV_SUM;
