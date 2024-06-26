DECLARE 
    @ReportDate DATE = '1900-01-01',
    @CSDate DATE = '1900-01-01',
    @Store INT = 0,
    @CureRate FLOAT = 0.055; -- Feature from analysis of Stage 3 accounts that manage to cure before potentially going to collection

-- Set @ReportDate and @CSDate if they are still the default value
IF @ReportDate = '1900-01-01'
BEGIN
    SELECT @ReportDate = MAX(SnapshotDate), @CSDate = MAX(SnapshotDate)
    FROM nystart.LoanPortfolioMonthly
    WHERE IsMonthEnd = 1;
END;

-- Drop temporary table if it exists
IF OBJECT_ID('tempdb..#base1') IS NOT NULL
    DROP TABLE #base1;

-- CTE to calculate total disbursed amounts per broker and month
WITH apps AS (
    SELECT 
        YEAR(DisbursedDate) * 100 + MONTH(DisbursedDate) AS YearMonth,
        CASE 
            WHEN Product = 'Nylån' THEN 'Nylån'  
            ELSE 'All' 
        END AS Product,
        BrokerName,
        SUM(Amount) AS Total
    FROM nystart.Applications A
    WHERE DisbursedDate IS NOT NULL
        AND IsMainApplicant = 1 
        AND SalesChannel = 'BROKER'
    GROUP BY YEAR(DisbursedDate) * 100 + MONTH(DisbursedDate), Product, BrokerName
),

-- CTE to add commission percent and total, based on nystart.BrokerCommissionSetup
commissionPct AS (
    SELECT 
        a.*,
        (CASE 
            WHEN a.BrokerName = 'Advisa' AND b.Product = 'ALL' THEN 
                CASE 
                    WHEN YearMonth < 202111 THEN 
                        CASE 
                            WHEN Total < 10000000 THEN 0.045 * Total 
                            ELSE 450000 + (Total - 10000000) * 0.0465 
                        END 
                    ELSE 0.05 * Total 
                END 
            ELSE (Total - PrevToAmount) * b.commissionPct + FixAmount 
        END) * 1.25 AS Commission,
        (CASE 
            WHEN a.BrokerName = 'Advisa' AND b.Product = 'ALL' THEN 
                CASE 
                    WHEN YearMonth < 202111 THEN 
                        CASE 
                            WHEN Total < 10000000 THEN 0.045 * Total 
                            ELSE 450000 + (Total - 10000000) * 0.0465 
                        END 
                    ELSE 0.05 * Total 
                END 
            ELSE (Total - PrevToAmount) * b.commissionPct + FixAmount 
        END) / Total AS CommissionPct
    FROM apps a
    LEFT JOIN nystart.BrokerCommissionSetup b
        ON a.BrokerName = b.BrokerName 
        AND (
            (a.Product = 'Nylån' AND (b.Product = 'Nylån' OR b.Product = 'ALL'))
            OR (a.Product <> 'Nylån')
        )
        AND YearMonth BETWEEN YEAR(b.ValidFrom) * 100 + MONTH(b.ValidFrom) 
                          AND YEAR(b.ValidTo) * 100 + MONTH(b.ValidTo)
        AND Total BETWEEN b.AmountFrom AND b.AmountTo
)



-- -- Select from commissionPct CTE where Product is 'Nylån'
-- SELECT * 
-- FROM commissionPct
-- WHERE Product = 'All';

		,	
		
		onl as ( -- online disbursals by year and month
		select Year(DisbursedDate)*100+Month(DisbursedDate) as YearMonth,count(*) as Acc,SUM(Amount) as Amt
		from nystart.Applications
		where DisbursedDate is not null
		and SalesChannel='WEB' and IsMainAPplicant=1
		group by Year(DisbursedDate)*100+Month(DisbursedDate)
		),
		onl2 as ( -- add monthly online acquisition cost from nystart.OnlineCost
		select onl.*,oc.Cost,oc.Cost/onl.Amt as OnlineCommission
		from onl join nystart.OnlineCost oc on oc.YearMonth=onl.YearMonth
		),
		tenor as (-- get the initial tenor on account (sometimes initial remaining tenure in table is original -1 (like 179, 143 etc.) that why it the max(remanining tenor) is odd then add 1)
		select AccountNumber,DisbursedDate,case when max(RemainingTenor)%2=1 then MAX(RemainingTenor)+1 else MAX(RemainingTenor) end as Tenor
		from nystart.LoanPortfolio
		group by AccountNumber,DisbursedDate
		)
		
		,

		base as ( -- combine the data together
		select 
		A.AccountNumber+'-'+cast(Row_number() over (partition by A.AccountNumber order by a.DisbursedDate) as varchar(2)) as UniqueKey,
		A.AccountNumber,
		A.DisbursedDate,
		ISNULL(lead(A.DisbursedDate) over (partition by A.AccountNumber order by A.DisbursedDate),'2199-12-31') as EndDate,
		Amount
		,StartupFee
		,isnull(tenor.Tenor,TenorMonths) as TenorMonths,
		SalesChannel,
		case when SalesChannel='BROKER' then CommissionPct*Amount 
			when SalesChannel='WEB' then ISNULL(onl2.OnlineCommission*Amount*1.25, 0.055*Amount*1.25) 
			else 0 
		 end as AcquisitionCost,
		A.BrokerName

		FROM nystart.Applications A
		LEFT JOIN onl2 ON onl2.YearMonth = YEAR(A.DisbursedDate) * 100 + MONTH(A.DisbursedDate) 
			AND A.SalesChannel = 'WEB'
		LEFT JOIN tenor ON tenor.AccountNumber = A.AccountNumber 
			AND tenor.DisbursedDate = A.DisbursedDate


		LEFT JOIN commissionPct P ON A.BrokerName = P.BrokerName and A.Product = P.Product

			--AND ((A.Product = 'Nylån' AND A.Product = P.Product) OR A.Product <> 'Nylån')

			AND (YEAR(A.DisbursedDate) * 100 + MONTH(A.DisbursedDate)) = P.YearMonth

		WHERE A.DisbursedDate IS NOT NULL 
			AND A.IsMainApplicant = 1
			
)


		-- populate final table with all the disbursed app, acuisition cost and some other details.
		select distinct base.*,LP.InterestRate,
			   LP.CurrentAmount as ReportingBalance,

			   case when CS.MOB<=2 then CS.AppliedApplicationScore else CS.AdjustedBehaviourScore end as PD,
			   -- cast(SUBSTRING(Stageing,6,1) as int) as RiskStage,
			   CS.Stageing as RiskStage  , 
			   CS.FBE,

			   IsOpen,
			   LP.RemainingTenor,
			   --isnull(LP.InvoicedInterest,0)-ISNULL(LP.PaidInterest,0) + ISNULL(LP.InvoicedFee,0)-ISNULL(LP.PaidFee,0) as InvoicedNotPaid /*using the old logic since I cannot access the InvNotP-table. Should be reversed in prod*/
			   ISNULL(inp.Amount,0) as InvoicedNotPaid	
		into #base1
		from nystart.LoanPortfolio LP
		join base
		on LP.AccountNUmber=base.AccountNumber
		and SnapshotDate=@ReportDate --and IsOpen=1
		left join nystart.InvoicedNotPaid inp on inp.AccountNumber=base.AccountNumber and inp.SnapshotDate=@ReportDate /*use this instead of the old invnotpaid logic*/
		left join   nystart.CustomerScores CS    on CS.AccountNumber=LP.AccountNumber and CS.SnapshotDate=LP.SnapshotDate; -- 	nystart.CustomerScore CS 




		-- get accounts which do not have corresponding application in the system
		IF OBJECT_ID('tempdb..#acc') is not null
			DROP TABLE #acc
		IF OBJECT_ID('tempdb..#acc1') is not null
			DROP TABLE #acc1
		select AccountNumber,DisbursedDate into #acc
		from nystart.LoanPortfolio where SnapshotDate=@ReportDate and AccountNumber not in (select AccountNumber from #base1) and DisbursedDate is not null;
		with startdate as 
		(select LP.AccountNUmber,MIN(SnapshotDate) as StartDate
		 from nystart.LoanPortfolio LP
		 join #acc a on a.AccountNumber=LP.AccountNumber
		 group by LP.AccountNUmber)
		select LP.AccountNumber,LP.DisbursedDate,LP.InterestRate,LP.OriginalAmount,LP.RemainingTenor
		into #acc1
		from nystart.LoanPortfolio LP
		join startdate on startdate.AccountNumber=LP.AccountNumber and LP.SnapshotDate=startdate.StartDate

		-- add these accounts to the main table table
		insert into #base1 
		select a.AccountNumber+'-1',
			   a.AccountNumber,
			   a.DisbursedDate,
			   '2199-12-31',
			   a.OriginalAmount,
			   0,
			   a.RemainingTenor,
			   'Missing',
			   0,
			   'Missing',
			   a.InterestRate,
			   LP.CurrentAmount,
			   
			   CS.AdjustedBehaviourScore as PD,
			   CS.Stageing as RiskStage,
			   CS.FBE,
		
			   LP.IsOpen,
			   LP.RemainingTenor,
			   ISNULL(inp.Amount,0) as InvoicedNotPaid	
		from #acc1 a
		join nystart.LoanPortfolio LP on a.AccountNumber=LP.AccountNumber and LP.SnapshotDate=@ReportDate
		left join   nystart.CustomerScores CS    on CS.AccountNumber=LP.AccountNumber and CS.SnapshotDate=LP.SnapshotDate
		left join nystart.InvoicedNotPaid inp on inp.AccountNumber=a.AccountNumber and inp.SnapshotDate=@ReportDate



		-- limit the table to accounts which were open at reporting date
		IF OBJECT_ID('tempdb..#base') is not null
			DROP TABLE #base;
		select UniqueKey,
			   AccountNumber,
			   DisbursedDate,
			   EndDate,
			   Amount,
			   StartupFee,
			   TenorMonths,
			   AcquisitionCost,
			   InterestRate,
			   ReportingBalance,
			   RiskStage,
			   PD,
			   InvoicedNotPaid
		into #base
		from #base1 
		where IsOpen=1 and EndDate>@ReportDate




/*Adding table with default dates due to data issues with the Defaultdate in the LoanPortfolio-table.
Sometimes there is no date, then we subsitute this date instead.*/
IF OBJECT_ID('tempdb..#DefaultDates') IS NOT NULL
	DROP TABLE #DefaultDates;
WITH DEF1 AS (
SELECT
AccountNumber,
SnapshotDate,
Stageing
, LAG(Stageing, 1, Stageing) OVER (PARTITION BY AccountNumber ORDER BY SnapshotDate DESC) LAG_STAGE
FROM nystart.CustomerScores
WHERE SnapshotDate = EOMONTH(SnapshotDate, 0)
)


, DEF2 AS (
SELECT
*
, EOMONTH(SNAPSHOTDATE, 1) AS Calc_DefDate

FROM DEF1

WHERE Stageing <> 'Stage3' AND LAG_STAGE = 'Stage3' AND EOMONTH(SNAPSHOTDATE, 1) <= @ReportDate
)





SELECT
AccountNumber
, MAX(Calc_DefDate) AS Calc_DefDate
INTO #DefaultDates
FROM DEF2
GROUP BY AccountNumber; 






/*Creating a master POCI-table. It got too messy to do inside the already big #result creation
This will take the latest forecast/recovery curve (not the original curve applicable at repurchase date) and calculate the gain/loss from that.*/
IF OBJECT_ID('tempdb..#RecoveryPOCI') IS NOT NULL
	DROP TABLE #RecoveryPOCI;

WITH TRANS1 AS (

SELECT
A.AccountNumber, A.SnapshotDate, B.SaleDate, DATEDIFF(MONTH, B.SaleDate, A.SnapshotDate) AS MID -- Months in default
, B.BoughtCapital, B.BoughtPrice
, ISNULL(C.PaidTotal,0) AS [Act Recov Mth kr] /*actual recovery per month in kr*/
, ISNULL(C.PaidTotal,0)/B.BoughtPrice AS [Act Recov Mth Pct] /*actual recovery per month in %*/

, ISNULL(D.MthRC_PolyModel,0) * B.BoughtCapital AS [Est Recov Mth kr]
, ISNULL(D.MthRC_PolyModel,0) AS [Est Recov Mth Pct]


, ISNULL(C.PaidTotal,0) - ISNULL(D.MthRC_PolyModel,0) * B.BoughtCapital AS [GainLoss realised coll] /*gain or loss from realised collection compared to estimated*/


FROM nystart.LoanPortfolio A
LEFT JOIN Hannes.RePurchase B ON A.AccountNumber = B.AccountNumber
LEFT JOIN (select AccountNumber,YearMonth,sum(Paidtotal) as PaidTotal from  Hannes.RePurchaseTrans group by AccountNUmber,YearMonth) C ON A.AccountNumber = C.AccountNumber AND year(A.SnapshotDate)*100+month(A.SnapshotDate) = C.YearMonth AND C.YearMonth <= year(@ReportDate)*100+month(@ReportDate)
LEFT JOIN nystart.RecoveryLGD D ON D.MonthsInDefault = DATEDIFF(MONTH, B.SaleDate, A.SnapshotDate)  AND B.SaleDate BETWEEN D.ValidFrom AND D.ValidTo
WHERE A.SnapshotDate = EOMONTH(A.SnapshotDate,0) AND A.SnapshotDate >= B.SaleDate  AND A.SnapshotDate <= @ReportDate
--ORDER BY A.AccountNumber, A.SnapshotDate
)










, SUM1 AS (SELECT
    AccountNumber,
    MID, /* Assuming MID is available in TRANS1 and you want to order the cumulative sum by this column */
    SUM([Act Recov Mth kr]) OVER (PARTITION BY AccountNumber ORDER BY MID) AS [Act Recov Acc kr],
    SUM([Act Recov Mth Pct]) OVER (PARTITION BY AccountNumber ORDER BY MID) AS [Act Recov Acc Pct],
    SUM([Est Recov Mth kr]) OVER (PARTITION BY AccountNumber ORDER BY MID) AS [Est Recov Acc kr],
    SUM([Est Recov Mth Pct]) OVER (PARTITION BY AccountNumber ORDER BY MID) AS [Est Recov Acc Pct],
    SUM([GainLoss realised coll]) OVER (PARTITION BY AccountNumber ORDER BY MID) AS [Sum GainLoss realised coll]
  FROM TRANS1
  --GROUP BY AccountNumber /* Adjusted to group by MID as well */
)




SELECT
A.*
, B.[Act Recov Acc kr], B.[Act Recov Acc Pct], B.[Est Recov Acc kr], B.[Est Recov Acc Pct], B.[Sum GainLoss realised coll]
INTO #RecoveryPOCI
FROM TRANS1 A
LEFT JOIN SUM1 B ON A.AccountNumber = B.AccountNumber and A.MID = B.MID ;
--ORDER BY A.AccountNumber, A.SnapshotDate













--#result table is a main table with model data
IF OBJECT_ID('tempdb..#result') is not null
	DROP TABLE #result
--populate the table with data as of reporting date
-- most of model columns are empty at this stage
select distinct LP.AccountNumber,


	   -- isnull(CS.RiskStage,CS2.RiskStage) AS RiskStage, -- risk stage and risk class can be taken as of date different than the reporting date

		CS.Stageing as RiskStage,
		CS.AdjustedBehaviourScore as PD,
		CS.FBE,
		--CS.ForbearanceName,

	   0 as Ord,
	   LP.SnapshotDate as Date,
	   LP.CurrentAmount as Base,
	   CAST(null as decimal(12,2)) as ContractualInterest,
	   cast(null as decimal(12,2)) as ContractualAmort,
	   cast(null as decimal(12,2)) as InterestIncomeByEIR,
	  -- cast(null as decimal(12,2)) as CashFlowsNPV,
	   cast(null as decimal(12,2)) as AmortizedCostBOP,
	   cast(null as decimal(12,2)) as AmortizedCostEOP,
	   cast(null as float) as EIR,
	   cast(null as float) as EIRmth,
	   cast(null as decimal(12,2)) as Annuity,
	   b.StartupFee,
	   b.AcquisitionCost,
	   b.StartupFee as StartupFeeLeft,
	   b.AcquisitionCost as AcquisitionCostLeft,
	   cast(0 as decimal(12,2)) as StartupFeeAmort,
	   cast(0 as decimal(12,2)) as AcquisitionCostAmort,
	   b.TenorMonths as OriginalTenor,
	   LP.RemainingTenor,
	   LP.DisbursedDate,
	   LP.InterestRate,
	   case when isnull(CS.Stageing,CS.Stageing)= 'Stage3'  then 180 else 36 end as ModelMonths,
	   
	   /*Old sloting for stage 3 lonas into FF-LGD or recovery curve LGD in the comment. 
	   New slotting for the AFS-idicator is based on the accountstatus and the fundingcompany.*/
	   --case when LP.DelinquencyStatusCode>=4 and LPprev.DelinquencyStatusCode<4 then 1 else 0 end as AFS,
	   CASE WHEN LP.AccountStatus in ('COLLECTION','FROZEN') THEN 0 --Fins det fall där man har coll status men är på EPB? Är det fel isåfall?
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany <> 'Erik Penser Bank AB' THEN 0
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany = 'Erik Penser Bank AB' THEN 1 
			ELSE 1
		END AS AFS, -- Available for sale
	   
	   isnull(b.InvoicedNotPaid,0) as InvoicedNotPaid,
	   F.FundingCompany,
	   /*Proposed change is to use the PD (score) per account that is actually scored to that specific account instead of an average of all accounts in the risk class*/
	   case when isnull(CS.Stageing,CS.Stageing) in ('Stage1','Stage2') 
	   
			 then power((1.0- isnull(CS.AdjustedBehaviourScore,CS.AdjustedBehaviourScore)),(1.0/case when CS.Stageing='Stage1' then 12 else 36 end))
			when CS.Stageing='Stage3' and LP.DelinquencyStatusCode>=4 and LPprev.DelinquencyStatusCode<4 then 0
	   End as SurvivalRate,
	   
	   /*Slotting for LGD is based on the same logic as the AFS indicator.
	   The two acctualy say the same thing - do we expect the account to be sold to Modhi or not?*/
	   case WHEN sc.AccountNumber is not null then SC.LGD
			WHEN LP.AccountStatus in ('COLLECTION','FROZEN') THEN ISNULL(R.LGDPerPeriod_Disco, R0.LGDPerPeriod_Disco) -- Use the LGD for the point (months in default) the account is in.
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany <> 'Erik Penser Bank AB' THEN R0.LGDPerPeriod_Disco -- the first point on the LGDcurve (discounted values) used for performing accounts on own book (no FF agreeement)
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany = 'Erik Penser Bank AB' THEN -- FF LGD according to agreement 
				 case when @ReportDate<'2023-06-30' then 
							 case when LP.CurrentAmount<=200000 then 0.365
								  else  0.441
							 end
					  when @ReportDate>='2023-06-30' and @ReportDate<'2024-01-31' then 
							 case when LP.CurrentAmount<=200000 then 0.3902 -- old value 0.365, changed on 2023-07-06
								  else 0.4731 -- old value 0.441, changed on 2023-07-06
							 end
					  when @ReportDate>='2024-01-31' then 0.38
				END
	   END AS LGD,
	   --ISNULL(R.LGDMultiplicator, 0) AS LGDMultiplicator,

	   /*prel values for cure rate. Andreas should estimate accurate values.*/
	   CASE WHEN LP.AccountStatus in ('COLLECTION','FROZEN') THEN 1.0 -- ingen cure hos inkasso
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany = 'Erik Penser Bank AB' THEN 1.0  - @CureRate -- säljs vid 105
			WHEN LP.AccountStatus not in ('COLLECTION','FROZEN') AND F.FundingCompany <> 'Erik Penser Bank AB' THEN 1.0 - @CureRate -- till inkasso vid 135
		END AS CureRate,
	   CAST(null as decimal(12,2)) as EAD,
	   CAST(null as decimal(6,4)) as MPD,
	   CAST(null as decimal(6,4)) as LPD,
	   CAST(null as decimal(12,2)) as ECL,
	   CAST(null as decimal(12,2)) as ECLNPV,
	  -- CAST(null as decimal(12,2)) as CashFlowsRC,
	  -- CAST(null as decimal(12,2)) as CashFlowsNPVRC,
	   DATEDIFF(month,LP.DisbursedDate,@ReportDate) as MOB,

	   
	   
	   /*added the month's in default at the current book end*/           ---previous logic
	--    CASE WHEN CS.Stageing <> 'Stage3' THEN CAST(NULL AS SUBSTRING)
	--     ELSE  DATEDIFF(MONTH, ISNULL(LP.DefaultDate, Def.Calc_DefDate), @ReportDate) END AS [MID], -- months in default


		CASE 
		WHEN CS.Stageing <> 'Stage3' THEN NULL
		ELSE DATEDIFF(MONTH, ISNULL(LP.DefaultDate, Def.Calc_DefDate), @ReportDate)
	END AS [MID]  -- months in default

	   /*added flags and empty columns for the POCI (re-purchased) accounts*/
	   ,CASE WHEN P.AccountNumber IS NOT NULL THEN 1 ELSE 0 END AS [POCI Status],
	   isnull(SC.EventTypeDesc,'') as SpecialCase,
	   CASE WHEN LP.AccountStatus in ('COLLECTION','FROZEN') THEN 1 ELSE 0 END AS [Collection status]

	   , RP.SaleDate
	   , RP.BoughtPrice 		 [Orig Amout]    --  BoughtPrice shall be the base for poci even though the asset is higher        
	   , CAST(NULL as FLOAT) AS [Gross CFNPV]
	   , RP.[Est Recov Acc kr] /*estimated accumulated recoveries up to @reportdate. This is the amortization according to the model*/
	   , RP.[Act Recov Acc kr] /*actual accumulated recoveries up to @reportdate*/
	   , RP.[Est Recov Mth kr] /*above but just the current month's recovery/estimate*/
	   , RP.[Act Recov Mth kr]
	   , RP.[GainLoss realised coll] AS [Monthly GainLoss realised coll] /*this is the current month's PnL effecto from realised collection. Anton should use this column*/
	   , RP.[Sum GainLoss realised coll] AS [Acc GainLoss realised coll] /*this is the total PnL effect from realised collection*/
	   , CAST(NULL as FLOAT) AS [Orig est monthly CF] /*should be filled later with the original future monthly estimated cashflow*/
	   , CAST(NULL as FLOAT) AS [Current est monthly CF] /*should be filled later with the current/new future monthly estimated cashflow*/
	   , CAST(NULL as FLOAT) AS [Orig est monthly CFNPV] 
	   , CAST(NULL as FLOAT) AS [Current est monthly CFNPV] 
	   , CAST(NULL as FLOAT) AS [Sum orig est CFNPV]  /*sum of above. filled and used later in POCI calculations*/
	   , CAST(NULL as FLOAT) AS [Sum current est CFNPV] 
	   , CAST(NULL as FLOAT) AS [Acc GainLoss revaluation]  /*the difference between the two discounted columns above is the gain or loss that affect the asset value and the PnL*/
		
into #result
from nystart.LoanPortfolio LP

	left join   nystart.CustomerScores CS    on CS.AccountNumber=LP.AccountNumber and CS.SnapshotDate=LP.SnapshotDate

	--  left join nystart.CustomerScore CS
	--  on CS.AccountNumber=LP.AccountNumber and CS.SnapshotDate=@CSDate
	--  left join nystart.CustomerScore CS2
	--  on CS2.AccountNumber=LP.AccountNumber and CS2.SnapshotDate=@ReportDate


	 left join #base b on b.AccountNumber=LP.AccountNumber
	 left join nystart.LoanPortfolio LPprev
	 on LP.AccountNumber=LPprev.AccountNumber and LPprev.SnapshotDate=DATEADD(day,-day(@ReportDate),@ReportDate)
	 left join nystart.Funding F on LP.AccountNumber=F.AccountNumber and @ReportDate between F.ValidFrom and F.ValidTo
	 /*adding joins to the recovery curve table and POCI-table
	 filter på #LGDRecov då man kan lägga till nya värden men spara gamla inställningar.
	 ev ska man alltid låsa in den EIR man använde vid köpet (POCI), i så fall får man filtrera så att CollectionDate eller DefaultDate BETWEEN ValidFrom/ValidTo*/
	 LEFT JOIN Hannes.RePurchase P ON LP.AccountNumber = P.AccountNumber AND P.SALEDATE <= @ReportDate
	 /*join in the currenct recovery curve*/
	 LEFT JOIN nystart.RecoveryLGD R ON  R.MonthsInDefault = DATEDIFF(MONTH, LP.DefaultDate, @ReportDate)+1 AND @ReportDate BETWEEN R.ValidFrom AND R.ValidTo
	 /*join in the original recovery curve applied at the repurchase date. Diff between orig and current is applied as a gain or loss (ECL)*/
	 LEFT JOIN nystart.RecoveryLGD Rorig ON  Rorig.MonthsInDefault = DATEDIFF(MONTH, LP.DefaultDate, @ReportDate)+1 AND P.SaleDate BETWEEN Rorig.ValidFrom AND Rorig.ValidTo
	 LEFT JOIN nystart.RecoveryLGD R0 ON R0.MonthsInDefault = 1 AND @ReportDate BETWEEN R0.ValidFrom AND R0.ValidTo
	 LEFT JOIN #DefaultDates Def ON Def.AccountNumber = LP.AccountNumber
	 LEFT JOIN #RecoveryPOCI RP ON RP.AccountNumber = LP.AccountNumber AND RP.SnapshotDate = @ReportDate
	 LEFT JOIN nystart.InvoicedNotPaid InpOrig on InpOrig.AccountNumber=LP.AccountNumber and InpOrig.SnapshotDate=EOMONTH(P.SaleDate,0) /*the original accrued interest and fees, inlcuded in the original asset value*/
	 LEFT JOIN nystart.SpecialCases SC on SC.AccountNumber=LP.AccountNumber and SC.ReportingDate=LP.SnapshotDate
where LP.IsOpen=1 and LP.SnapshotDate=@ReportDate






and b.AccountNumber = 5004544








--replace remaining tenor=0 with 1
update #result set RemainingTenor=1 where RemainingTenor<=0;

--in case that number of months to model is longer than remaining tenor, model will be caluclated only till remaining tenor
/*Adjusting how ModelMonths is set. 
IF performing, MM = MIN( 36 , remaining maturity)
IF stage 3 and not expected to be sold (e.g., on collection), MM = 180months - Months In Default, i.e., how long is remaining on the recovery curve. Potentially check for off-by-one-error, should the MM be 180 - MID +1?
IF stage 3 and expected to be sold (AFS=1) then set MM to 1, i.e., expect to get one cashflow of outstandingbalance * FF LGD*/
update #result set ModelMonths = RemainingTenor where ModelMonths > RemainingTenor AND RiskStage IN ('Stage1','Stage2');
update #result set ModelMonths = 180 - MID + 1 where RiskStage = 'Stage3' and [Collection status] = 1 AND [POCI Status] = 1 AND AFS = 0; /*acc in own book, repurchased acc, POCI, use recovery curve*/
update #result set ModelMonths = 180 - MID + 1 where RiskStage = 'Stage3' AND [Collection status] = 0 AND [POCI Status] = 0 AND AFS = 0; /*acc in own book, no FF sale, will go into recovery curve*/
--update #result set ModelMonths = 1 where RiskStage = 3 AND [Collection status] = 1 AND [POCI Status] = 0 AND AFS = 0; /*acc on recovery curve but not POCI*/
--update #result set ModelMonths = 1 where RiskStage = 3 AND [Collection status] = 0 AND [POCI Status] = 0 AND AFS = 1; /*acc in EPB, FF future sale*/


--populate amortized and left startup fee and acquisition cost 
/*uncahnged. just added my own fnAmortize function since I cannot access it. My function is a mirror of Piotr's.*/
update #result set StartupFeeAmort=Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,StartupFee,MOB),
				   StartupFeeLeft=StartupFee-Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,StartupFee,MOB),
				   AcquisitionCostAmort=Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,AcquisitionCost,MOB),
				   AcquisitionCostLeft=AcquisitionCost-Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,AcquisitionCost,MOB),

				   AmortizedCostEOP=Base+AcquisitionCost-Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,AcquisitionCost,MOB)
									-StartupFee+Hannes.fnAmortize(case when ModelMonths<36 then ModelMonths else 36 end,StartupFee,MOB);

--set model months to 180 for Risk Stage = 3 (regardless of real remaining tenor)
/*Remove since the ModelMonth is set above for all cases.*/
--update #result
--set ModelMonths=180
--where RiskStage=3;

-- calculate the annuity and effective interest rate as of reporting date
with tmp as (
select a.AccountNumber,EIR.Annuity,EIR.EIR
from #result a
/*Question, using 36m even for Stage 1? Maybe it has no impact?*/
outer apply dbo.fnEIR(a.InterestRate
						,case when a.RiskStage='Stage3' then 180 else 36 end
						, case when a.RiskStage='Stage3' then 180 else a.RemainingTenor end
						,a.Base
						,a.AmortizedCostEOP) EIR
WHERE a.RiskStage <> 'Stage3'
)
update #result set EIR=tmp.EIR,
				   Annuity=tmp.Annuity,
				   EIRmth=(POWER((1 + tmp.EIR),(1.0/12))) - 1 
from #result 
join tmp on tmp.AccountNumber=#result.AccountNumber;





/*new update for stage 3 loans. should we also separate those available for sale? Though I would guess the interest rate should be the "interna rate" for those as well.*/
with tmp as (
select a.AccountNumber,EIR.Annuity,EIR.EIR
from #result a
LEFT JOIN nystart.RecoveryLGD B ON A.MID = B.MonthsInDefault AND @ReportDate BETWEEN B.ValidFrom AND B.ValidTo
--LEFT JOIN nystart.RecoveryLGD B ON A.MID = B.MOB AND @ReportDate BETWEEN B.ValidFrom AND B.ValidTo
outer apply dbo.fnEIR(CASE WHEN A.[POCI Status] = 0 THEN B.Discount_NPL WHEN A.[POCI Status] = 1 THEN B.Discount_POCI END
						, A.ModelMonths -- always model months, ie. how long we estimate we will get recoveries/cashflows
						, A.ModelMonths
						, a.Base
						, a.AmortizedCostEOP) EIR -- shoudl we add +A.InvoicedNotPaid to get the whole amortizedcost? seems like it has only been forgotten when the invoicenotpaid was added to the model
WHERE a.RiskStage = 'Stage3' and a.[POCI Status] = 0
)


update #result set EIR=tmp.EIR,
				   Annuity=tmp.Annuity,
				   EIRmth=(POWER((1 + tmp.EIR),(1.0/12))) - 1 
from #result 
join tmp on tmp.AccountNumber=#result.AccountNumber;

update #result
set EIR = POWER(1+b.Discount_POCI,12)-1,
	EIRmth = b.Discount_POCI
from #result a
left join nystart.RecoveryLGD b on b.MonthsInDefault = 1 AND a.SaleDate BETWEEN B.ValidFrom AND B.ValidTo /*lock in the discount rate to the original discount rate. Saledate and not @reportdate*/
--left join nystart.RecoveryLGD b on b.MOB = 1 AND a.SaleDate BETWEEN B.ValidFrom AND B.ValidTo /*lock in the discount rate to the original discount rate. Saledate and not @reportdate*/
where a.RiskStage = 'Stage3' and a.[POCI Status] = 1



;





SELECT * from #result









-- ------------------------------- CONTROL CORRECT # & AMT  --------------------------------------------------------------------

-- -- Declare variables to store results from the first query
-- DECLARE @Count1 INT, @Sum1 DECIMAL(18,2);

-- -- Execute the first query and store its results
-- SELECT @Count1 = COUNT(AccountNumber), @Sum1 = SUM(Base)
-- FROM #result
-- WHERE Ord = 0;

-- -- Declare variables for the second query
-- DECLARE @Count2 INT, @Sum2 DECIMAL(18,2);

-- -- Execute the second query and store its results
-- SELECT @Count2 = COUNT(AccountNumber), @Sum2 = SUM(CurrentAmount)
-- FROM nystart.LoanPortfolioMonthly
-- WHERE SnapshotDate = @ReportDate AND IsOpen = 1;

-- -- Output the comparison result along with the values from both queries
-- DECLARE @ComparisonResult VARCHAR(50);
-- SELECT @ComparisonResult = 
--   CASE 
--     WHEN @Count1 = @Count2 AND @Sum1 = @Sum2 THEN 'Values are identical'
--     ELSE 'Values are not identical'
--   END

-- -- Output the comparison result along with the values from both queries
-- SELECT @ComparisonResult AS ComparisonResult, @Count1 AS 'Count1', @Sum1 AS 'Sum1', @Count2 AS 'Count2', @Sum2 AS 'Sum2';

-- -- Check if values are not identical and stop execution if they are not
-- IF @ComparisonResult = 'Values are not identical'
-- BEGIN
--     PRINT 'Stopping execution as the values are not identical.'
--     RETURN; -- Stops the script
-- END

-- ------------------------------- CONTROL CORRECT # & AMT  --------------------------------------------------------------------



DECLARE 

-- @ReportDate date='2024-01-31',
-- @CSDate date='1900-01-01',


-- @ReportDate date=@ReportDate,
-- @CSDate date='1900-01-01',
@max int, @i int=1,@txt varchar(500)
select @max=MAX(ModelMonths) from #result;



--main loop: in each pass one month of data is populated basing on previous month data 
WHILE @i<=@max
	BEGIN
		SET @txt='Starting pass no: '+cast(@i as varchar(4))
		RAISERROR( @txt,0,1) WITH NOWAIT;
		insert into #result
		select r.AccountNumber,
			   r.RiskStage,
			   r.PD,
			   r.FBE,
			   --r.ForbearanceName,
			  
			   @i as Ord,
			   EOMONTH(dateadd(month,1,r.Date)) as Date,

			   -- outstanding balance: previous month base decreased by thim month contractual amortization 
			   r.Base-(case when r.Annuity-r.Base*r.InterestRate/12>r.Base then r.Base else r.Annuity-r.Base*r.InterestRate/12 end) as Base,

			   --contractual interest: monthly interest rate applied to previous month balance (base)
			   r.Base*r.InterestRate/12 as ContractualInterest, 

			   --contractual amortization: annuity amount decreased by contractual interest
			   case when r.Annuity-r.Base*r.InterestRate/12>r.Base then r.Base else r.Annuity-r.Base*r.InterestRate/12 end as ContractualAmort, 

			   -- interest income by EIR: amortized cost BOP (EOP from prev month) * monthyl EIR
			   r.AmortizedCostEOP*r.EIRmth as InterestIncomeByEIR, 

			   -- NPV cash flow (not populated for FF candidates): Annuity amount / (1+EIRmth)^@i+1
			   --case when r.RiskStage=3 and r.AFS=1 then null else (r.Annuity)/POWER(1+(r.EIRmth),@i+1) end as CashFlowsNPV,

			   -- prev momths EOP becomes new months BOP
			   r.AmortizedCostEOP as AmortizedCostBOP,

			   --Amortized cost end of period: this month base (Base - contractual amort) + acquistion cost left - startup fee left 
			   /*Question. Is the amortization of Acq and Start up here equal to the one in the fnAmortize? If not, do we get a missmatch between the AmCoEOP and if adding all values separately?
			   We could check one account that has less remaining maturity than 36months between two book end months - The amortization of the acq cost make sense?*/
			   /*Might need a another handlng for stage 3 loans? NPL on EPB should only have one row (sold to Modhi next month), POCIs and recovery curve LGDs should have a balance each future month (current calculation)*/
			   r.Base-(r.Annuity-r.Base*r.InterestRate/12)+r.AcquisitionCostLeft-r.AcquisitionCostLeft/case when r.ModelMonths-@i+1<36 
																											then r.ModelMonths-@i+1 
																											else 36 
																									   end
					-r.StartupFeeLeft+r.StartupFeeLeft/case when r.ModelMonths-@i+1<36 
															then r.ModelMonths-@i+1 
															else 36  
													   end,

			   r.EIR, 
			   r.EIRmth, 
			   r.Annuity,
			   r.StartupFee,
			   r.AcquisitionCost,

			   --Startup fee left: each month 1/36th of prev month left amount gets amortized
			   r.StartupFeeLeft-r.StartupFeeLeft/case when r.ModelMonths-@i+1<36 then r.ModelMonths-@i+1 else 36 end as StartupFeeLeft,

			   --Acquisition cost left: each month 1/36th of prev month left amount gets amortized
			   r.AcquisitionCostLeft-r.AcquisitionCostLeft/case when r.ModelMonths-@i+1<36 then r.ModelMonths-@i+1 else 36 end as AcquisitionCostLeft,-- 1/36th of remaining acq cost got amortized

			   --startup fee amortized: increased by amortized amount
			   r.StartupFeeAmort+r.StartupFeeLeft/case when r.ModelMonths-@i+1<36 then r.ModelMonths-@i+1 else 36 end,

			   --Acquisition cost amortized: increased by amortized amount
			   r.AcquisitionCostAmort+r.AcquisitionCostLeft/case when r.ModelMonths-@i+1<36 then r.ModelMonths-@i+1 else 36 end,

			   r.OriginalTenor,
			   r.RemainingTenor-1,
			   r.DisbursedDate,
			   r.InterestRate,
			   r.ModelMonths,
			   r.AFS,
			   r.InvoicedNotPaid,
			   r.FundingCompany,
			   r.SurvivalRate,
			   /*If the account is in collection, use the monthyl recovery curve value instead of the fixed LGD value */
			   r.LGD ,
			   --r.LGDMultiplicator,
			   /*cure rate added*/
			   r.CureRate,

			   --EAD (exposure at default): amortized cost EOP + Invoiced not paid amount,
			   --for risk stage 1 and 2 it's delayed by 3 months, for FF candidates it's only in first month (data as if reporting date)
			   /*no change. EAD is populated when needed.*/
			   case when r.RiskStage in ('Stage1','Stage2') and @i<=case when r.RiskStage='Stage1' then 12 else 36 end 
						then r3.AmortizedCostEOP+r3.InvoicedNotPaid
					when r.RiskStage='Stage3' and r.[POCI Status]=0 and @i=1 then r.AmortizedCostEOP+r.InvoicedNotPaid	
			   end as EAD,

			   --MPD (marginal PD, not calculated for FF candidates): 1 - survival rate in month 1, then 1-(1-prev month MPD)*survival rate
			   case when r.RiskStage='Stage3' then 1.0
					when @i=1 then 1-r.SurvivalRate else 1-(1-r.MPD)*r.SurvivalRate 
			   end as MPD,

			   --LPD (lifetime PD) - same as MPD in month 1, then MPD-MPD from prev month
			   case when r.RiskStage='Stage3' then 1.0
					when @i=1 then 1-r.SurvivalRate else 1-(1-r.MPD)*r.SurvivalRate-r.MPD 
			   end as LPD,
			   
			   r.ECL, --placeholder, will be populated in next steps
			   r.ECLNPV, --placeholder, will be populated in next steps

			   --cash flows according to recovery curve (stage 3 only): 70% of annuity
			   /*Re-using the column. Calculating the future cashflows for stage 3 loans on the recovery curve.
				POCI handling will be added here or to a separate column later*/
			  -- case when r.AFS = 0 and r.RiskStage=3  then r.LGDMultiplicator * Rec.RecoveryOrigBalanceMth * (R0.AmortizedCostEOP + R0.InvoicedNotPaid) else null end  as CashFlowsRC,

			   --NPV of cash flows according to recovery curve (stage 3 only): CashFlowsRC/(1+EIR mth)^i
			   /*Re-using the column. Calculating the future discounted cashflows for stage 3 loans on the recovery curve.
				POCI handling will be added here or to a separate column later*/
			   --case when r.AFS= 0 and r.RiskStage=3 then (r.LGDMultiplicator * Rec.RecoveryOrigBalanceMth * (R0.AmortizedCostEOP + R0.InvoicedNotPaid))/POWER((1+r.EIRmth),@i) else null end  as CashFlowsNPVRC,
			   
			   r.MOB+1 as MOB,
			   
			   /*add new columns*/
			   
			   CASE WHEN r.RiskStage = 'Stage3' THEN r.MID + 1 ELSE CAST(NULL AS INT) END,
				r.[POCI Status],
				r.SpecialCase,
				r.[Collection status]

			   , r.SaleDate
			   , r.[Orig Amout]
			   , r.[Gross CFNPV],

				-- get the future cashflow 
			   --,case when @i > 0 then   ISNULL(Rorig.MthRC_PolyModel,0) * B.BoughtCapital else r.[Est Recov Acc kr] end as [Est Recov Acc kr]
			   r.[Est Recov Acc kr]


			    /*estimated accumulated recoveries up to @reportdate. This is the amortization according to the model*/
			   , r.[Act Recov Acc kr] /*actual accumulated recoveries up to @reportdate*/


			   ,case when @i > 0 then   ISNULL(Rorig.MthRC_PolyModel,0) * (B.BoughtCapital ) else r.[Est Recov Mth kr] end as [Est Recov Mth kr]  -- + r.InvoicedNotPaid

			   
			    /*above but just the current month's recovery/estimate*/



			   , r.[Act Recov Mth kr]

			   , r.[Monthly GainLoss realised coll] /*this is the current month's PnL effecto from realised collection. Anton should use this column*/
			   , r.[Acc GainLoss realised coll] /*this is the total PnL effect from realised collection*/

			   , Rorig.MthRC_PolyModel * B.BoughtCapital AS [Orig est monthly CF] /*should be filled later with the original future monthly estimated cashflow*/
			   , Rcurr.MthRC_PolyModel * B.BoughtCapital AS [Current est monthly CF] /*should be filled later with the current/new future monthly estimated cashflow*/
			   
			   , (Rorig.MthRC_PolyModel * (B.BoughtCapital   )) / POWER(1 + r.EIRmth, @i) AS [Orig est monthly CFNPV]    -- + r.InvoicedNotPaid
			   , (Rcurr.MthRC_PolyModel * B.BoughtCapital) / POWER(1 + r.EIRmth, @i)  AS [Current est monthly CFNPV] 

			   , r.[Sum orig est CFNPV] 
			   , r.[Sum current est CFNPV] 
			   , r.[Acc GainLoss revaluation]  /*the difference between the two discounted columns above is the gain or loss that affect the asset value and the PnL*/
			   -- måste lägga till summan av månatliga CF

		from #result r    
		left join #result r3 on r.AccountNumber=r3.AccountNumber and r3.Ord=case when @i<=3 then 0 else @i-3 end
		/*join status per the book end date (ord = 0)*/
		LEFT JOIN #result R0 ON r.AccountNumber=R0.AccountNumber AND R0.Ord = 0
		/*		Join status from last months' AcqCost. Used to see the month's amortization for POCIs.
		Will be changed when we have the new POCI trasnaction tabel. Development is underway, not finished.*/
		LEFT JOIN Nystart.AcquisitionCostNew APrev ON Aprev.AccountNumber = r.AccountNumber AND Aprev.Date = Aprev.ReportDate AND Aprev.Reportdate = EOMONTH(dateadd(month,-@i,r.Date))
		/*join in the currenct recovery curve. 
		Here or in the calculation above we need to make sure that e.g., skuldsannering and dödsbo is taken care of, given its own recovery curve*/
		 --LEFT JOIN nystart.RecoveryLGD Rcurr ON  Rcurr.MOB = r.MID + 1 AND @ReportDate BETWEEN Rcurr.ValidFrom AND Rcurr.ValidTo
		 LEFT JOIN nystart.RecoveryLGD Rcurr ON  Rcurr.MonthsInDefault = r.MID + 1 AND @ReportDate BETWEEN Rcurr.ValidFrom AND Rcurr.ValidTo
		 /*join in the original recovery curve applied at the repurchase date. Diff between orig and current is applied as a gain or loss (ECL)*/
		 LEFT JOIN nystart.RecoveryLGD Rorig ON  Rorig.MonthsInDefault = r.MID + 1 AND r.SaleDate BETWEEN Rorig.ValidFrom AND Rorig.ValidTo

		 --LEFT JOIN nystart.RecoveryLGD Rorig ON  Rorig.MOB = r.MID + 1 AND r.SaleDate BETWEEN Rorig.ValidFrom AND Rorig.ValidTo
		 LEFT JOIN Hannes.RePurchase B ON r.AccountNumber = B.AccountNumber

		where r.Ord=@i-1
		and @i<=r.ModelMonths  
		
		AND r.AccountNumber = 5004544
		;

		--calculate ECL
		update #result
			SET ECL=EAD*LPD*LGD*CureRate 
		where Ord=@i and [POCI Status] = 0 /*removed POCI from the regular caluclation. ECL updated before loop*/

		--calculate ECLNPV
		update #result
			SET ECLNPV=ECL/POWER(1+EIRmth,Ord)	
		where Ord=@i and [POCI Status] = 0
		
		
		
		;

	SET @i=@i+1 --increase the counter
END;



SELECT * from #result



-- TO Caluclate the cumulative SUM of Esimated POCI Recovery

;WITH CTE AS (
    SELECT
        AccountNumber,
		Ord,
        [Est Recov Mth kr],
        SUM([Est Recov Mth kr]) OVER (PARTITION BY AccountNumber ORDER BY ORD -1 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
    FROM #result
    WHERE [POCI Status] = 1
)
UPDATE r
SET r.[Est Recov Acc kr] = c.RunningTotal
FROM #result r
left JOIN CTE c ON r.AccountNumber = c.AccountNumber AND r.Ord = c.Ord;


--WHERE r.[POCI Status] = 1;



--SELECT * from #result WHERE [POCI Status] = 1 and AccountNumber = 7739527  order by Ord



-- SELECT * from #result where AccountNumber = '7207202'


--  --  DECLARE @REPORTDATE AS DATE = '2023-12-31';
-- --prepare the main loop
-- DECLARE 
-- @ReportDate date='2024-02-29',
-- @CSDate date='1900-01-01',
-- @max int, @i int=1,@txt varchar(500)
-- select @max=MAX(ModelMonths) from #result;


	--end of main loop

	--Populate final month data
	with summ as (
	select AccountNumber,SUM(case when Ord=0 then Base else 0 end) as OrigAmount,SUM(case when Ord<Modelmonths then  ContractualAmort else 0 end) as AmortSum
	from #result
	group by AccountNumber
	)
	update #result set ContractualAmort=OrigAmount-AmortSum, Base=0
	from #result r join summ on r.AccountNumber=summ.AccountNumber and r.Ord=ModelMonths and RemainingTenor>0;

	update #result set --CashFlowsNPV=(ContractualInterest+ContractualAmort)/POWER(1+(EIRmth),Ord),
				 --InterestIncomeByEIR=ContractualInterest+ContractualAmort-AmortizedCostBOP,
			      AmortizedCostEOP=0,
				  StartupFeeAmort=StartupFee,
				  StartupFeeLeft=0,
				  AcquisitionCostAmort=AcquisitionCost,
				  AcquisitionCostLeft=0
	where Ord=ModelMonths;


	

--prepare POCI loop
WITH SUM1 AS (
SELECT
AccountNumber
/*the discounted value of all future expected cashflows is the asset value (will be adjusted by diff between estimated and actual cashflows or revaluations later)*/
, SUM([Orig est monthly CFNPV] ) AS [Sum future Orig CF]
, SUM([Current est monthly CFNPV]) AS [Sum future Curr CF]
FROM #result
WHERE [POCI Status] = 1 
GROUP BY AccountNumber
)
UPDATE #result
/*acqusition cost is retained from the original credit granting and added here and amortized 1/36 each month
InvoiceNotPaid (unpaid interest and fees) are added later as with the regular amco. 
InvoiceNotPaid are not included in the saleprice but are not written off so somehow Nstart is just gifted this part of the asset.*/
SET AmortizedCostEOP = B.[Sum future Orig CF] + A.AcquisitionCostLeft - A.StartupFeeLeft
, [Sum orig est CFNPV] = B.[Sum future Orig CF]
, [Sum current est CFNPV] = B.[Sum future Curr CF]
, [Acc GainLoss revaluation] = B.[Sum future Curr CF] - B.[Sum future Orig CF]
, [Gross CFNPV] = B.[Sum future Orig CF]
, InterestIncomeByEIR = B.[Sum future Orig CF] * A.EIRmth /*calculation for POCI's interest income. Uses the original gross value * original EIR. 
   Interest income is locked in at the repurchase time. If the loan is written down or something, the interes income is adjsted in the impairment gain or loss*/
FROM #result A
LEFT JOIN SUM1 B ON A.AccountNumber = B.AccountNumber
WHERE B.AccountNumber IS NOT NULL AND A.Ord = 0 AND A.[POCI Status] = 1;

UPDATE #result
/*acqusition cost is retained from the original credit granting and added here and amortized 1/36 each month
InvoiceNotPaid (unpaid interest and fees) are added later as with the regular amco. 
InvoiceNotPaid are not included in the saleprice but are not written off so somehow Nstart is just gifted this part of the asset.*/
SET ECL = 0
, ECLNPV = 0
FROM #result A
WHERE A.[POCI Status] = 1;


--DECLARE @max int, @i int,@txt varchar(500)
SET @i = 1;
SELECT @max=MAX(ModelMonths) FROM #result WHERE [POCI Status] = 1;

-- start by adding the asset value per future month
WHILE @i<=@max
	BEGIN
		SET @txt='Starting POCI pass no: '+cast(@i as varchar(4))
		RAISERROR( @txt,0,1) WITH NOWAIT;
		
		/*set BOP as prev EOP*/
		WITH PREV AS (
		SELECT
		AccountNumber
		, AmortizedCostEOP
		FROM #result
		WHERE [POCI Status] = 1 AND Ord = @i-1
		)
		UPDATE #result
		/*update the BOP value*/
		SET AmortizedCostBOP = B.AmortizedCostEOP
		FROM #result R
		LEFT JOIN PREV B ON R.AccountNumber = B.AccountNumber
		WHERE R.[POCI Status] = 1 AND R.Ord = @i;

		/*set interest rate and amortization
		Not certain calculations work as intended anymore. Though this is just for filling in future period's values which have no impact on the book value. 
		Book value at current period (ord = 0) is set above before the loop.*/
		UPDATE #result
		SET ContractualInterest = A.EIRmth * A.AmortizedCostBOP
		, InterestIncomeByEIR = A.EIRmth * A.AmortizedCostBOP
		/*amortization is nominal monthly recovery minus interest rate*/
		, ContractualAmort = A.[Orig est monthly CF] - (A.EIRmth * A.AmortizedCostBOP) /*need to make sure what curve should be used. Orig or current??*/
		, AmortizedCostEOP = A.AmortizedCostBOP - (A.[Orig est monthly CF] - (A.EIRmth * A.AmortizedCostBOP)) + A.AcquisitionCostLeft - A.StartupFeeLeft
		FROM #result A
		WHERE A.Ord = @i AND A.[POCI Status] = 1 



	SET @i=@i+1 --increase the counter
END;	





SELECT * from #result 

--where AccountNumber = 7207202 order by Ord




-- DECLARE 

-- -- @ReportDate date='2024-02-29',
-- -- @CSDate date='1900-01-01',

-- @max int, @i int=1,@txt varchar(500)  

-- select @max=MAX(ModelMonths) from #result;


--store data in the table
/*OBS removed during testing sicne we are testing in prod*/
-- delete from nystart.AcquisitionCostNew where ReportDate=@ReportDate
--insert into nystart.AcquisitionCostNew
IF OBJECT_ID('tempdb..#AcqCost') is not null
	DROP TABLE #AcqCost;
select @ReportDate as ReportDate,
		--'2023-12-31' as ReportDate,
	   *,
	   case when FundingCompany='Erik Penser Bank AB' then 1 else 0 end as EPB_FLAG,
	   SUM(ECL) over (partition by AccountNumber) as ECL_SUM ,
	   SUM(ECLNPV) over (partition by AccountNumber) as ECLNPV_SUM,
	   CAST(NULL AS FLOAT) AS [Acc Impar GainLoss] /*the total accumulated gain or loss per acc. Only the reval G/L affects the book value.*/
into #AcqCost
from #result;

UPDATE #AcqCost
SET [Acc Impar GainLoss] = ISNULL([Acc GainLoss realised coll],0) + ISNULL([Acc GainLoss revaluation],0)
FROM #AcqCost;
print 'delete'




-- tar bort all data
--DELETE  from nystart.AcquisitionCostPOCI_24

-- -- vad det låter som
-- DROP TABLE  nystart.AcquisitionCostPOCI_24;

--SELECT * from nystart.AcquisitionCostPOCI_24

--delete from nystart.AcquisitionCostPOCI_24  where ReportDate='2024-05-31' --@ReportDate
-- print 'insert'


-- IF TABEL EXIST AND WANT TO LOAD MORE COLUMNS 
insert into nystart.AcquisitionCostPOCI_24

SELECT
ReportDate
, Date
, Ord
, AccountNumber
, RiskStage
,FBE

, DisbursedDate
, OriginalTenor
, RemainingTenor
, MOB
, MID
, ModelMonths
, InterestRate
, EIR
, EIRmth
, Base AS CurrentAmount
, InvoicedNotPaid
,cast( [Orig Amout] as Decimal(12,2)) as [Orig Amount] --only valid for POCI. the original bought balance
, cast([Gross CFNPV] as Decimal(12,2)) as [Gross CFNPV]--only valid for POCI. the remaining discounted CF from original estimate
, AmortizedCostBOP
, AmortizedCostEOP
, cast(AcquisitionCost as decimal(12,2)) as AcquisitionCost
, StartupFee
, AcquisitionCostAmort
, StartupFeeAmort
, cast(AcquisitionCostLeft as decimal(12,2)) as AcquisitionCostLeft
, StartupFeeLeft
, FundingCompany
, EPB_FLAG
, [Collection status]
, [POCI Status]
, [SaleDate]


, cast([Est Recov Acc kr] as decimal(12,2)) as [Est Recov Acc kr]  -- estimated recovery on POCI Account until today
, cast([Act Recov Acc kr] as decimal(12,2)) as [Act Recov Acc kr] 
, cast([Act Recov Acc kr] as decimal(12,2))  -  cast([Act Recov Acc kr] as decimal(12,2))  as [Realised G/L Acc]
, cast([Est Recov Mth kr] as decimal(12,2)) as [Est Recov Mth kr]
, cast([Act Recov Mth kr] as decimal(12,2)) as [Act Recov Mth kr]



, cast([Sum orig est CFNPV] as decimal(12,2)) as [Sum orig est CFNPV]
, cast([Sum current est CFNPV] as decimal(12,2)) as [Sum current est CFNPV]
, cast([Sum current est CFNPV]-[Sum orig est CFNPV] as decimal(12,2)) as [1397 Credit losses POCI]
, cast([Sum current est CFNPV]-[Sum orig est CFNPV] as decimal(12,2)) as [1397 Credit gain POCI]
, cast(CASE WHEN [Monthly GainLoss realised coll] <= 0 THEN [Monthly GainLoss realised coll] ELSE 0 END as decimal(12,2)) AS [8082 Monthly Loss Relised collect]
, cast(CASE WHEN [Monthly GainLoss realised coll] > 0 THEN [Monthly GainLoss realised coll] ELSE 0 END as decimal(12,2)) AS [8083 Monthly Gain Relised collect] 
, cast(CASE WHEN [Acc GainLoss revaluation] <= 0 THEN [Acc GainLoss revaluation] ELSE 0 END as decimal(12,2)) AS [8080 Acc Loss Revaluation] 
, cast(CASE WHEN [Acc GainLoss revaluation] > 0 THEN [Acc GainLoss revaluation] ELSE 0 END as decimal(12,2)) AS [8081 Acc Gain Revaluation] 
, cast(CASE WHEN [POCI Status] = 0 THEN 0 ELSE InterestIncomeByEIR END as decimal(12,2)) AS [3341 InterestIncomeByCAEIR]
, ECL_SUM
, ECLNPV_SUM
, Base
,ECLNPV
, ECL
, MPD
,SpecialCase
,case when SpecialCase <> '' then 1 else 0 end as SpecialCaseFlag

-- if creating tabel first time
--INTO nystart.AcquisitionCostPOCI_24

FROM #AcqCost where ord=0



SELECT top(111) * from nystart.AcquisitionCostPOCI_24



DECLARE 

@ReportDate date='1900-01-01',
@CSDate date='1900-01-01' ,
@Store int=0,
@CureRate float=0.055    -- Feature from analysis of Stage 3 accounts that manage to cure before potentially going to collection

IF @ReportDate='1900-01-01'
	BEGIN
		SELECT @ReportDate=max(SnapshotDate),@CSDate=max(SnapshotDate) 
		from nystart.LoanPortfolioMonthly where IsMonthEnd=1
	END


SELECT
*

FROM nystart.AcquisitionCostPOCI_24
WHERE ord = 0 and ReportDate=@ReportDate
--and AccountNumber = '7832322'
order by [POCI Status] desc, [Collection status] desc, RiskStage desc;


-- list of accounts with acquistion cost
select AccountNUmber,DisbursedDate,Amount,StartupFee,cast(AcquisitionCost as decimal(12,2)) as AcquisitionCost,SalesChannel,BrokerName
from #base1
where Year(DisbursedDate)>=YEAR(@ReportDate);

--acquisition cost summary
select YEAR(DisbursedDate)*100+MONTH(DisbursedDate) as YearMonth,SalesChannel,BrokerName,SUM(Amount) AS Amount,SUM(StartupFee) as StartupFee,SUM(AcquisitionCost) as AcquisitionCost
from #base1
where Year(DisbursedDate)>=YEAR(@ReportDate)
group by YEAR(DisbursedDate)*100+MONTH(DisbursedDate),SalesChannel,BrokerName;



-- -- END

-- -- GO


