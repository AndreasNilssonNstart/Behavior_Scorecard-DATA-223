WITH DelinquencyInfo AS 
(
    SELECT DISTINCT
        LP.SnapshotDate,
        LP.AccountNumber,

        MAX(CASE
            WHEN DelinquencyStatusCode = 9 THEN 9 
            WHEN NumberOfLateStatements >= 5 THEN 5 
            ELSE DelinquencyStatusCode
        END) AS Delinquency,
        MAX(CASE
            WHEN PFM.AccountNumber IS NOT NULL THEN 1
            ELSE 0
        END) AS FBE,
        SUM(LP.CurrentAmount) AS Balance
    FROM nystart.LoanPortfolio LP
    LEFT JOIN nystart.Applications A ON A.AccountNumber = LP.AccountNumber AND A.DisbursedDate = LP.DisbursedDate
    LEFT JOIN nystart.PaymentFreeMonths PFM ON LP.AccountNumber = PFM.AccountNumber 
                                             AND YEAR(LP.SnapshotDate) * 100 + MONTH(LP.SnapshotDate) = PFM.YearMonth
    WHERE LP.SnapshotDate > DATEADD(MONTH, -1, GETDATE())

          --AND LP.AccountNumber = 7165236 -- 5777172

          -- Ensure SnapshotDate is the last day of its month by checking if adding one day shifts to a new month
          AND DATEADD(DAY, 1, LP.SnapshotDate) = DATEADD(MONTH, DATEDIFF(MONTH, 0, LP.SnapshotDate) + 1, 0)
    GROUP BY LP.SnapshotDate, LP.AccountNumber
)


,

deli1 as (

select *,
       MAX(case when Delinquency=1 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last1DateE,
       MAX(case when Delinquency=2 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last30DateE,
       MAX(case when Delinquency=3 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last60DateE,
       MAX(case when Delinquency=4 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last90DateE,
       MAX(case when Delinquency=5 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last120DateE,
       MAX(case when Delinquency>1 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last30Date,
       MAX(case when Delinquency>2 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last60Date,
       MAX(case when Delinquency>3 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last90Date,
       MAX(case when Delinquency>4 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as Last120Date,
       MAX(case when FBE=1 then SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between unbounded preceding and current row) as LastFBEDate,
       Min(case when Delinquency>1 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as Next30Date,
       Min(case when Delinquency>2 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as Next60Date,
       Min(case when Delinquency>3 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as Next90Date,
       Min(case when Delinquency>4 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as Next120Date,
       Min(case when Delinquency=9 then  SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as NextFrozenDate,
       Min(case when FBE=1 then SnapshotDate else null end) over (partition by AccountNumber  order by SnapshotDate rows between 1 following and unbounded following) as NextFBEDate  --

from DelinquencyInfo ) 

,

deliFinal2  as (
select d1.*,
       datediff(DAY,d1.Last30DateE,d1.SnapshotDate) as TimeSince30,
       datediff(DAY,d1.Last60DateE,d1.SnapshotDate) as TimeSince60,
       datediff(DAY,d1.Last90DateE,d1.SnapshotDate) as TimeSince90,
       datediff(DAY,d1.Last120DateE,d1.SnapshotDate) as TimeSince120,
       case when DATEADD(month,6,d1.Last30Date)>=d1.SnapshotDate then 1 else 0 end as Ever30In6Months,
       case when DATEADD(month,12,d1.Last30Date)>=d1.SnapshotDate then 1 else 0 end as Ever30In12Months,
       case when d1.Last30Date is not null then 1 else 0 end as Ever30,
       case when DATEADD(month,6,d1.Last60Date)>=d1.SnapshotDate then 1 else 0 end as Ever60In6Months,
       case when DATEADD(month,12,d1.Last60Date)>=d1.SnapshotDate then 1 else 0 end as Ever60In12Months,
       case when d1.Last60Date is not null then 1 else 0 end as Ever60,
       case when DATEADD(month,6,d1.Last90Date)>=d1.SnapshotDate then 1 else 0 end as Ever90In6Months,
       case when DATEADD(month,12,d1.Last90Date)>=d1.SnapshotDate then 1 else 0 end as Ever90In12Months,
       case when d1.Last90Date is not null then 1 else 0 end as Ever90,
       case when DATEADD(month,6,d1.Last120Date)>=d1.SnapshotDate then 1 else 0 end as Ever120In6Months,
       case when DATEADD(month,12,d1.Last120Date)>=d1.SnapshotDate then 1 else 0 end as Ever120In12Months,
       case when d1.Last120Date is not null then 1 else 0 end as Ever120,
       case when DATEADD(month,6,d1.Last120Date)>=d1.SnapshotDate then 5
            when DATEADD(month,6,d1.Last90Date)>=d1.SnapshotDate then 4
            when DATEADD(month,6,d1.Last60Date)>=d1.SnapshotDate then 3
            when DATEADD(month,6,d1.Last30Date)>=d1.SnapshotDate then 2
            when DATEADD(month,6,d1.Last1DateE)>=d1.SnapshotDate then 1
            else 0
       end as WorstDelinquency6M,
       case when DATEADD(month,12,d1.Last120Date)>=d1.SnapshotDate then 5
            when DATEADD(month,12,d1.Last90Date)>=d1.SnapshotDate then 4
            when DATEADD(month,12,d1.Last60Date)>=d1.SnapshotDate then 3
            when DATEADD(month,12,d1.Last30Date)>=d1.SnapshotDate then 2
            when DATEADD(month,12,d1.Last1DateE)>=d1.SnapshotDate then 1
            else 0
       end as WorstDelinquency12M,
       case when d1.Last120Date IS not null then 5
            when d1.Last90Date IS not null then 4
            when d1.Last60Date is not null then 3
            when d1.Last30Date is not null then 2
            when d1.Last1DateE is not null then 1
            else 0
       end as WorstDelinquency,
       datediff(DAY,d1.LastFBEDate,d1.SnapshotDate) as TimeSinceFBE,
       case when DATEADD(month,6,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn6Months,
       case when DATEADD(month,12,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn12Months,
       case when DATEADD(month,24,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn24Months,
       case when DATEADD(month,36,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn36Months, --
       case when DATEADD(month,48,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn48Months,
       case when d1.LastFBEDate is not null then 1 else 0 end as EverFBE,
       case when d1.Next30Date<= DATEADD(year,1,d1.SnapshotDate) then 1 else 0 end as Ever30After12Months,
       case when d1.Next30Date<= DATEADD(year,2,d1.SnapshotDate) then 1 else 0 end as Ever30After24Months,
       case when d1.Next30Date<= DATEADD(year,3,d1.SnapshotDate) then 1 else 0 end as Ever30After36Months,
       case when d1.Next30Date<= DATEADD(year,4,d1.SnapshotDate) then 1 else 0 end as Ever30After48Months,
       case when d1.Next60Date<= DATEADD(year,1,d1.SnapshotDate) then 1 else 0 end as Ever60After12Months,  
       case when d1.Next60Date<= DATEADD(year,2,d1.SnapshotDate) then 1 else 0 end as Ever60After24Months,  
       case when d1.Next60Date<= DATEADD(year,3,d1.SnapshotDate) then 1 else 0 end as Ever60After36Months,  
       case when d1.Next60Date<= DATEADD(year,4,d1.SnapshotDate) then 1 else 0 end as Ever60After48Months,  
       case when d1.Next90Date<= DATEADD(year,1,d1.SnapshotDate) then 1 else 0 end as Ever90After12Months,
       case when d1.Next90Date<= DATEADD(year,2,d1.SnapshotDate) then 1 else 0 end as Ever90After24Months,
       case when d1.Next90Date<= DATEADD(year,3,d1.SnapshotDate) then 1 else 0 end as Ever90After36Months,
       case when d1.Next90Date<= DATEADD(year,4,d1.SnapshotDate) then 1 else 0 end as Ever90After48Months,
       case when d1.Next120Date<= DATEADD(year,1,d1.SnapshotDate) then 1 else 0 end as Ever120After12Months,
       case when d1.Next120Date<= DATEADD(year,2,d1.SnapshotDate) then 1 else 0 end as Ever120After24Months,
       case when d1.Next120Date<= DATEADD(year,3,d1.SnapshotDate) then 1 else 0 end as Ever120After36Months,
       case when d1.Next120Date<= DATEADD(year,4,d1.SnapshotDate) then 1 else 0 end as Ever120After48Months,
       case when d1.NextFrozenDate<= DATEADD(year,1,d1.SnapshotDate) then 1 else 0 end as FrozenAfter12Months,
       case when d1.NextFrozenDate<= DATEADD(year,2,d1.SnapshotDate) then 1 else 0 end as FrozenAfter24Months,
       case when d1.NextFrozenDate<= DATEADD(year,3,d1.SnapshotDate) then 1 else 0 end as FrozenAfter36Months,
       case when d1.NextFrozenDate<= DATEADD(year,4,d1.SnapshotDate) then 1 else 0 end as FrozenAfter48Months

from deli1 d1
--where IsMonthEnd=1 
) 



,

deliFinal1 as (

select d1.*,
      
       d30.Balance as ExposureAtFirst30,
       d60.Balance as ExposureAtFirst60,
       df.Balance as ExposureAtFirstFrozen

from deliFinal2 d1

left join deli1 d30 on  d1.AccountNumber =d30.AccountNumber  and d30.SnapshotDate=d1.Next30Date
left join deli1 d60 on  d1.AccountNumber =d60.AccountNumber  and d60.SnapshotDate=d1.Next60Date
--left join #deli1 d90 on  d1.ACCOUNTNUMBER =d90.ACCOUNTNUMBER  and d90.SnapshotDate=d1.Next90Date
--left join #deli1 d120 on  d1.ACCOUNTNUMBER =d120.ACCOUNTNUMBER  and d120.SnapshotDate=d1.Next120Date
left join deli1 df on  d1.AccountNumber =df.AccountNumber  and df.SnapshotDate=d1.NextFrozenDate

),

deliFinal as (

select d1.*,
       d90.Balance as ExposureAtFirst90,
       d120.Balance as ExposureAtFirst120

from deliFinal1 d1
left join deli1 d90 on  d1.AccountNumber =d90.AccountNumber  and d90.SnapshotDate=d1.Next90Date
left join deli1 d120 on  d1.AccountNumber =d120.AccountNumber  and d120.SnapshotDate=d1.Next120Date

)

,

base1   as (

select  LP.SnapshotDate,

       LP.AccountNumber,
       LP.IsOpen,
       case when LP.IsOpen=1 and DelinquencyStatus='Frozen' then 'FROZEN'
            when LP.IsOpen=1 and DelinquencyStatus<>'Frozen' then 'OPEN'
            else 'CLOSED'
       end as AccountStatus,
       CurrentAmount,
       MOB,
       LP.DisbursedDate as DisbursedDate,
       RemainingTenor,
       1-IsMainApplicant as CoappFlag,
       case when A.Kronofogden=1 then 1 else 0 end as Kronofogden,
       case when isnull(A.Kronofogden,0)=0 then 1 else 0 end as NoKronofogden,

       DelinquencyStatusCode as CurrentDelinquencyStatus,
       FBE,
      TimeSince30,  
      TimeSince60,  
      TimeSince90,  
      TimeSince120, 
      Ever30In6Months,
      Ever30In12Months, 
      dF.Ever30,    
      Ever60In6Months,  
      Ever60In12Months, 
      dF.Ever60,    
      Ever90In6Months,  
      Ever90In12Months, 
      dF.Ever90,    
      Ever120In6Months, 
      Ever120In12Months,    
      dF.Ever120,   
      WorstDelinquency6M,   
      WorstDelinquency12M,  
      WorstDelinquency  ,
      TimeSinceFBE, 
      EverFBEIn6Months, 
      EverFBEIn12Months,    
      EverFBEIn24Months,    
      EverFBEIn36Months,    
      EverFBEIn48Months,    
      EverFBE,  
      Ever30After12Months,
      Ever60After12Months,  
      Ever90After12Months,  
      Ever120After12Months, 
      FrozenAfter12Months,
      Ever30After24Months,
      Ever60After24Months,  
      Ever90After24Months,  
      Ever120After24Months, 
      FrozenAfter24Months,
      Ever30After36Months,
      Ever60After36Months,  
      Ever90After36Months,  
      Ever120After36Months, 
      FrozenAfter36Months,
      Ever30After48Months,
      Ever60After48Months,  
      Ever90After48Months,  
      FrozenAfter48Months,
      datediff(Month,LP.DisbursedDate,Next30Date) as TimeToFirst30,
      datediff(Month,LP.DisbursedDate,Next60Date) as TimeToFirst60,
      datediff(Month,LP.DisbursedDate,Next90Date) as TimeToFirst90,
      datediff(Month,LP.DisbursedDate,Next120Date) as TimeToFirst120,
      datediff(Month,LP.DisbursedDate,NextFrozenDate) as TimeToFirstFrozen,
      ExposureAtFirst30,
      ExposureAtFirst60,
      ExposureAtFirst90,
      ExposureAtFirst120,
      ExposureAtFirstFrozen

   
from deliFinal dF  

inner join nystart.LoanPortfolio LP  on dF.AccountNUmber= LP.AccountNumber and LP.SnapshotDate= dF.SnapshotDate

left join  nystart.Applications A           on A.AccountNumber=LP.AccountNumber and A.DisbursedDate=LP.DisbursedDate
left join nystart.PaymentFreeMonths PFM     on LP.AccountNumber=PFM.AccountNumber and YEAR(LP.SnapshotDate)*100+Month(LP.SnapshotDate)=YearMonth

where  DATEADD(DAY, 1, LP.SnapshotDate) = DATEADD(MONTH, DATEDIFF(MONTH, 0, LP.SnapshotDate) + 1, 0)

) 



,


LatestStatus AS (
    SELECT 
        AccountNumber, 
        MAX(StartDate) AS LastStartDate
    FROM 
        [Reporting-db].[nystart].[Forbearance]
    WHERE 
        ForbearanceName  IN ('Permanent interest cut', 'Extension of maturity','Temporary interest cut','Capitalization')
    GROUP BY 
        AccountNumber
),

LatestForberanceStatus as (

SELECT f.AccountNumber, f.StartDate as forberanceDate , ForbearanceName ,f.StartDate ,f.EndDate

FROM 
    [Reporting-db].[nystart].[Forbearance] AS f
INNER JOIN 
    LatestStatus AS l ON f.AccountNumber = l.AccountNumber AND f.StartDate = l.LastStartDate
WHERE 
    f.ForbearanceName  IN ('Permanent interest cut', 'Extension of maturity','Temporary interest cut','Capitalization')

) , 

ForberanceLogic as (  

SELECT b.*, 
       l.forberanceDate,
           CASE
        WHEN (b.SnapshotDate BETWEEN l.StartDate AND l.EndDate)  and (b.WorstDelinquency <4)  then 1 -- or another value indicating true
        ELSE 0 -- or another value indicating false
    END AS FBE_eftergift

       ,CASE WHEN DATEADD(month, 3, l.forberanceDate) > b.SnapshotDate AND b.SnapshotDate >= l.forberanceDate THEN 1 ELSE 0 END as ForberanceIn3Months,
       CASE WHEN DATEADD(month, 6, l.forberanceDate) > b.SnapshotDate AND b.SnapshotDate >= l.forberanceDate THEN 1 ELSE 0 END as ForberanceIn6Months,
       CASE WHEN DATEADD(month, 9, l.forberanceDate) > b.SnapshotDate AND b.SnapshotDate >= l.forberanceDate THEN 1 ELSE 0 END as ForberanceIn9Months,
       CASE WHEN DATEADD(month, 12, l.forberanceDate) > b.SnapshotDate AND b.SnapshotDate >= l.forberanceDate THEN 1 ELSE 0 END as ForberanceIn12Months
FROM base1 as b
LEFT JOIN LatestForberanceStatus as l ON b.AccountNumber = l.AccountNumber

)

,allt as ( SELECT

 distinct  b.*  --,cs.Score,cs.RiskClass ,cs.Stage

from ForberanceLogic b
--left join nystart.CustomerScore cs on cs.AccountNumber=b.AccountNumber and cs.SnapshotDate=b.SnapshotDate)
)

SELECT * from allt

order by SnapshotDate

