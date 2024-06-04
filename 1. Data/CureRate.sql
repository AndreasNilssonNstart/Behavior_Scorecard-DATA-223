
-- THIS CODE CHECK HOW MANY ACCOUNT WILL RELATIVELY HAVE DEFAULTED ON THE PORTFOLIO 12 MONTH AFTER A SPECIFIC POINT

with J22 as (

  SELECT --TOP (1000) 

AccountNumber , CurrentAmount ,DelinquencyStatusCode , AccountStatus , IsOpen

  
  FROM [reporting-db].[nystart].[LoanPortfolioMonthly]

  --where AccountNumber = 7217557 and 
  
  where DelinquencyStatusCode = 4  and SnapshotDate  =  '2022-01-31' 

  ) 

,

N22 as  (

      SELECT 

j.AccountNumber , j.CurrentAmount ,n.CurrentAmount as CurrentAmount_n    ,n.DelinquencyStatusCode as DelinquencyStatusCode_n  , j.AccountStatus as IsOpen

  
  FROM J22 as j 
  
  left join [reporting-db].[nystart].[LoanPortfolioMonthly] as n  on j.AccountNumber = n.AccountNumber   
  
   where  n.SnapshotDate  =  '2023-09-30' --  and  n.DelinquencyStatusCode <>9


  ) 

SELECT  *  from N22 



