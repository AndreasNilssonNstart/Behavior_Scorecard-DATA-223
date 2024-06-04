


with base as (
SELECT   * --  SnapshotDate , count(AccountNumber) as count  

from nystart.LoanPortfolio

where 

--SnapshotDate in ('2020-01-31','2020-02-29','2022-06-30','2023-03-31')  

 IsOpen = 1  and 
 AccountStatus = 'OPEN' 
 and DATEADD(DAY, 1, SnapshotDate) = DATEADD(MONTH, DATEDIFF(MONTH, 0, SnapshotDate) + 1, 0)

 
-- group by SnapshotDate
-- order by SnapshotDate
)
,

both  as (

SELECT b.* 

,c.Stage 

from base as b 

inner join nystart.CustomerScore as c ON b.AccountNumber = c.AccountNumber  and b.SnapshotDate = c.SnapshotDate

)


SELECT    SnapshotDate , count(AccountNumber) as count  

from both 

where Stage in (1,2)

group by SnapshotDate
order by SnapshotDate




-- select top(100) * from  nystart.LoanPortfolio

-- select top(100) * from nystart.CustomerScore




SELECT  SnapshotDate, AccountNumber, DisbursedDate  ,CurrentAmount , MOB , DelinquencyStatusCode ,Ever90 ,AccountStatus ,IsOpen 
from nystart.LoanPortfolioMonthly

where AccountNumber  =      5450705 




-- Kontrollera konton i olika perioder

  -- 23-03 7192586 ,5074182 7216708  
  
  
    -- 21-01     5000229 5039615 5416821



    -- 22-01     5208616  5450705




SELECT TOP (1000) [AccountNumber]
      ,[AccountStatus]
      ,[SnapshotDate]
      ,[MOB]
      ,[DisbursedDate]
      ,[CurrentAmount]
      ,[RemainingTenor]
      ,[CoappFlag]
      ,[Ever30In6Months]
      ,[WorstDelinquency6M]
      ,[CurrentDelinquencyStatus]
      ,[WorstDelinquency12M]
      ,[Ever30In12Months]
      ,[Ever90In12Months]
      ,[Score]
      ,[RiskClass]
      ,[P]
      ,[BehaviourModel]
      ,[Ever90]
      ,[ForberanceIn6Months]
      ,[ForberanceIn12Months]
      ,[FBE_eftergift]
      ,[PDScoreNew]
      ,[UCScore]
      ,[age]
      ,[Inquiries12M]
      ,[PropertyVolume]
      ,[AdmissionModel]
      ,[ApplicationScore]
      ,[AppliedApplicationScore]
      ,[AdjustedBehaviourScore]
      ,[PD_Delta]
      ,[FBE]
      ,[SICR]
      ,[Stageing]
      ,[Date]
      ,[Instrument Rolling Mean]
  FROM [reporting-db].[nystart].[ECLInput]



  SELECT  stageing ,  avg(AdjustedBehaviourScore) as AdjustedBehaviourScore , avg(Score) as Score


    FROM [reporting-db].[nystart].[ECLInput]

    group by stageing


  SELECT    avg(AdjustedBehaviourScore) as AdjustedBehaviourScore , avg(Score) as Score


    FROM [reporting-db].[nystart].[ECLInput]

    WHERE Stageing <> 'Stage3'

