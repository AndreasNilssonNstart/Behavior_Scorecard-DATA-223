IF OBJECT_ID('tempdb..#deli') is not null
	DROP TABLE #deli
select SnapshotDate,
	   A.SSN,
	   max(case when DelinquencyStatusCode=9 then 9 
	   when NumberOfLateStatements>=5 then 5 else DelinquencyStatusCode end) Delinquency,
	   MAX(case when PFM.AccountNumber is not null then 1 else 0 end) as FBE,
	   SUM(CurrentAmount) as Balance,
	   IsMonthEnd
into #deli
from nystart.LoanPortfolio LP
join  nystart.Applications A
on A.AccountNumber=LP.AccountNumber and A.DisbursedDate=LP.DisbursedDate
left join nystart.PaymentFreeMonths PFM
on LP.AccountNumber=PFM.AccountNumber and YEAR(LP.SnapshotDate)*100+Month(LP.SnapshotDate)=YearMonth
left join nystart.DateDim DD on LP.SnapshotDate=DD.Date

--where LP.AccountNumber = '5544507'

 --LP.AccountNumber = '5544507' and 

group by SnapshotDate,SSN,IsMOnthEnd;
​
CREATE CLUSTERED INDEX idx1 on #deli(SnapshotDate,SSN)
IF OBJECT_ID('tempdb..#deli1') is not null
	DROP TABLE #deli1
select *,
	   MAX(case when Delinquency=1 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last1DateE,
	   MAX(case when Delinquency=2 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last30DateE,
	   MAX(case when Delinquency=3 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last60DateE,
	   MAX(case when Delinquency=4 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last90DateE,
	   MAX(case when Delinquency=5 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last120DateE,
	   MAX(case when Delinquency>1 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last30Date,
	   MAX(case when Delinquency>2 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last60Date,
	   MAX(case when Delinquency>3 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last90Date,
	   MAX(case when Delinquency>4 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as Last120Date,
	   MAX(case when FBE=1 then SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between unbounded preceding and current row) as LastFBEDate,
	   Min(case when Delinquency>1 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as Next30Date,
	   Min(case when Delinquency>2 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as Next60Date,
	   Min(case when Delinquency>3 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as Next90Date,
	   Min(case when Delinquency>4 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as Next120Date,
	   Min(case when Delinquency=9 then  SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as NextFrozenDate,
	   Min(case when FBE=1 then SnapshotDate else null end) over (partition by SSN order by SnapshotDate rows between 1 following and unbounded following) as NextFBEDate
​
into #deli1
from #deli
create clustered index ci_ssn_dt on #deli1 (SSN,SnapshotDate)
​
​
if OBJECT_ID('tempdb..#deliFinal2') is not null
	DROP TABLE #deliFinal2
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
	   case when DATEADD(month,36,d1.LastFBEDate)>=d1.SnapshotDate then 1 else 0 end as EverFBEIn36Months,
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
into #deliFinal2
from #deli1 d1
where IsMonthEnd=1
create clustered index ci_ssn_dt on #deliFinal2 (SSN,SnapshotDate)
​
​
if OBJECT_ID('tempdb..#deliFinal1') is not null
	DROP TABLE #deliFinal1
select d1.*,
	  
	   d30.Balance as ExposureAtFirst30,
	   d60.Balance as ExposureAtFirst60,
	   df.Balance as ExposureAtFirstFrozen
into #deliFinal1
from #deliFinal2 d1
left join #deli1 d30 on  d1.SSN=d30.SSN and d30.SnapshotDate=d1.Next30Date
left join #deli1 d60 on  d1.SSN=d60.SSN and d60.SnapshotDate=d1.Next60Date
--left join #deli1 d90 on  d1.SSN=d90.SSN and d90.SnapshotDate=d1.Next90Date
--left join #deli1 d120 on  d1.SSN=d120.SSN and d120.SnapshotDate=d1.Next120Date
left join #deli1 df on  d1.SSN=df.SSN and df.SnapshotDate=d1.NextFrozenDate
create clustered index ci_ssn_dt on #deliFinal1 (SSN,SnapshotDate)
​
​
​
if OBJECT_ID('tempdb..#deliFinal') is not null
	DROP TABLE #deliFinal
select d1.*,
	   d90.Balance as ExposureAtFirst90,
	   d120.Balance as ExposureAtFirst120
into #deliFinal
from #deliFinal1 d1
left join #deli1 d90 on  d1.SSN=d90.SSN and d90.SnapshotDate=d1.Next90Date
left join #deli1 d120 on  d1.SSN=d120.SSN and d120.SnapshotDate=d1.Next120Date
​
​
IF OBJECT_ID('tempdb..#base') is not null
	DROP TABLE #base
select LP.SnapshotDate,
	   D.IsMonthEnd,
	   LP.AccountNumber,
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
	   A.SSN,
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
	  WorstDelinquency	,
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

into #base1	   
from nystart.LoanPortfolio LP
join  nystart.Applications A
on A.AccountNumber=LP.AccountNumber and A.DisbursedDate=LP.DisbursedDate
left join nystart.PaymentFreeMonths PFM
on LP.AccountNumber=PFM.AccountNumber and YEAR(LP.SnapshotDate)*100+Month(LP.SnapshotDate)=YearMonth
join nystart.DateDim D on D.Date=LP.SnapshotDate and IsMonthEnd=1
join #deliFinal dF on dF.SSN=A.SSN and LP.SnapshotDate=dF.SnapshotDate
drop table #base




select b.*,cs.Score,cs.RiskClass
into #base 
from #base1 b
left join nystart.CustomerScore cs on cs.AccountNumber=b.AccountNumber and cs.SnapshotDate=b.SnapshotDate


​
update #base set Ever30After12Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<12
update #base set Ever60After12Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<12
update #base set Ever90After12Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<12
update #base set FrozenAfter12Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<12
update #base set Ever30After24Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<24
update #base set Ever60After24Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<24
update #base set Ever90After24Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<24
update #base set FrozenAfter24Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<24
update #base set Ever30After36Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<36
update #base set Ever60After36Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<36
update #base set Ever90After36Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<36
update #base set FrozenAfter36Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<36
update #base set Ever30After48Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<48
update #base set Ever60After48Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<48
update #base set Ever90After48Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<48
update #base set FrozenAfter48Months=-1 where DATEDIFF(month,SnapshotDate,'2023-10-31')<48
​
select * from #base

