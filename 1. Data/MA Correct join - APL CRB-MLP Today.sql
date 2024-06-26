


WITH

LPM_less12M_Accounts AS (
SELECT DISTINCT [AccountNumber]
     , max(mob) as max_mob               --,SnapshotDate
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly]
    WHERE  mob <= 12 and  IsMonthEnd = 1 --and AccountNumber = '7129596'
    GROUP by AccountNumber   ),


thirtyAtThree AS (
SELECT DISTINCT [AccountNumber]
     ,Ever30
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly]
    WHERE  mob = 3 and  IsMonthEnd = 1 --and AccountNumber = '7129596'
      ),




DEL90 AS (
    SELECT DISTINCT L.AccountNumber ,T.Ever30 ,L.Ever90 ,L.DisbursedDate ,L.MOB      --,SnapshotDate
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly] as L
    inner join LPM_less12M_Accounts as A on L.AccountNumber =A.AccountNumber and L.MOB = A.max_mob  

    inner join thirtyAtThree as T on L.AccountNumber =T.AccountNumber  ) 
    
    
    
    ,





DEL90_Applications_MaxDate AS (
    SELECT 

        D.Ever30,
        D.Ever90,
        A.AccountNumber,
        A.ApplicationID,
        A.[SSN] as SSN_A,
        A.PDScoreNew,
        A.ApplicationScore,
        A.[IsMainApplicant],
        --A.[ApplicantNo],
        A.[HasCoapp],      

        A.[ReceivedDate],
        A.[DisbursedDate],
        A.[Amount],
        A.InterestRate,
        A.[StartupFee],
        --A.[UCScore],
        A.[PaymentRemarks],
        A.[CreditOfficer],
        A.[SalesChannel],
        A.[Product],
        A.[Migrated],
        A.[BrokerName],
        A.[OriginalSalesChannel],
        A.[BirthDate],
        A.[Bookingtype],
        A.[MaritalStatus],
        A.[EmploymentType],
        A.[HousingType],
        A.[MonthlySalary],   
        A.[Referer],
        A.[Campaign],
        A.[SourceMedium],
        A.[Keyword],
        A.[NystartChannel],
        A.[PNReceivedDate],
        A.[NumberOfApplicants],
        A.[Gender],
        A.[CoappSameAddress],
        A.[Kronofogden],
        A.[CreditCardsNo],
        A.[InstallmentLoansNo],
        A.[UnsecuredLoansNo],
        A.[LastPaymentRemarkDate] as LastPaymentRemarkDate1,
        A.[TotalLoans],
        A.[NystartBalance],
        A.[TotalUnsecuredLoans]


    FROM 
        [Reporting-db].[nystart].[Applications] as A
    FULL JOIN DEL90 D ON A.AccountNumber = D.AccountNumber  and A.DisbursedDate =  D.DisbursedDate

    where IsMainApplicant = 1 and HasCoapp = 0  and A.[Status] = 'DISBURSED' 

    -- GROUP BY D.AccountNumber , A.SSN, A.DisbursedDate ,A.Status

    
),   -- Expected 568 rows --

 main AS (

SELECT row_number() over (partition by AccountNumber,DA.SSN_A order by CBR.Date desc) as RowNumber

-- additional features


   --,CBR.ssn     -- CBR.SSN  --DA.Status, CBR.*
    
   ,DA.* 

   ,
    CBR.[SSN],
    CBR.[jsonID],
    CBR.[Date],
    CBR.[import_key],
    CBR.[SSN2],
    CBR.[Inquiries12M],
    CBR.[CountyCode],
    CBR.[MunicipalityCode],
    CBR.[PostalCode],
    CBR.[GuardianAppointed],
    CBR.[BlockCode],
    CBR.[BlockCodeDate],
    CBR.[CivilStatus],
    CBR.[CivilStatusDate],
    CBR.[TimeOnAddress],
    CBR.[AddressType],
    CBR.[Country],
    CBR.[RiskPrognos] as UCScore,
    CBR.[IncomeYear],
    CBR.[ActiveBusinessIncome],
    CBR.[PassiveBusinessIncome],
    CBR.[EmploymentIncome],
    CBR.[CapitalIncome],
    CBR.[CapitalDeficit],
    CBR.[GeneralDeductions],
    CBR.[ActiveBusinessDeficit],
    CBR.[TotalIncome],
    CBR.[IncomeYear2],
    CBR.[ActiveBusinessIncome2],
    CBR.[PassiveBusinessIncome2],
    CBR.[EmploymentIncome2],
    
    CBR.[CapitalIncome2],
    CBR.[CapitalDeficit2],
    CBR.[GeneralDeductions2],
    CBR.[ActiveBusinessDeficit2],
    CBR.[TotalIncome2],
    CBR.[IncomeBeforeTax],
    CBR.[IncomeBeforeTaxPrev],
    CBR.[IncomeFromCapital],
    CBR.[DeficitFromCapital],
    CBR.[IncomeFromOwnBusiness],
    CBR.[PaymentRemarksNo],
    CBR.[PaymentRemarksAmount],
    CBR.[LastPaymentRemarkDate],
    CBR.[KFMPublicClaimsAmount],
    CBR.[KFMPrivateClaimsAmount],
    CBR.[KFMTotalAmount],
    CBR.[KFMPublicClaimsNo],
    CBR.[KFMPrivateClaimsNo],
    CBR.[HouseTaxValue],
    CBR.[HouseOwnershipPct],
    CBR.[HouseOwnershipStatus],
    CBR.[HouseOwnershipNo],
    
    CBR.[BusinessInquiries],
    CBR.[CreditCardsUtilizationRatio],
    CBR.[HasMortgageLoan],
    CBR.[HasCard],
    CBR.[HasUnsecuredLoan],
    CBR.[HasInstallmentLoan],
    CBR.[IndebtednessRatio],
    CBR.[AvgIndebtednessRatio12M],
    CBR.[ActiveCreditAccounts],
    CBR.[NewUnsecuredLoans12M],
    CBR.[NewInstallmentLoans12M],
    CBR.[NewCreditAccounts12M],
    CBR.[NewMortgageLoans12M],
    CBR.[TotalNewExMortgage12M],
    CBR.[VolumeChange12MExMortgage],
    CBR.[VolumeChange12MUnsecuredLoans],
    CBR.[VolumeChange12MInstallmentLoans],
    CBR.[VolumeChange12MCreditAccounts],
    CBR.[VolumeChange12MMortgageLoans],
    CBR.[AvgUtilizationRatio12M],
    CBR.[VolumeUsed],
    CBR.[NumberOfAccounts],
    CBR.[NumberOfLenders],
    CBR.[ApprovedCreditVolume],
    CBR.[InstallmentLoansVolume],
    CBR.[CreditAccountsVolume],
    CBR.[UnsecuredLoansVolume],
    CBR.[MortgageLoansHouseVolume],
    CBR.[MortgageLoansApartmentVolume],
    CBR.[NumberOfCredits],
    CBR.[NumberOfCreditors],
    CBR.[ApprovedCardsLimit],
    CBR.[NumberOfCreditCards],
    CBR.[NumberOfBlancoLoans],
    CBR.[SharedVolumeExMortgage],
    CBR.[SharedVolume],
    CBR.[NumberOfUnsecuredLoans],
    CBR.[SharedVolumeUnsecuredLoans],
    CBR.[NumberOfInstallmentLoans],
    CBR.[SharedVolumeInstallmentLoans],
    CBR.[NumberOfCreditAccounts],
    CBR.[SharedVolumeCrerditAccounts],
    CBR.[UtilizationRatio],
    CBR.[CreditAccountOverdraft],
    CBR.[NumberOfMortgageLoans],
    CBR.[SharedVolumeMortgageLoans],
    CBR.[SharedVolumeCreditCards]

FROM DEL90_Applications_MaxDate  as DA

LEFT JOIN [Reporting-db].[nystart].[CreditReportsBase] CBR ON CBR.SSN = DA.SSN_A  and (DATEDIFF(day, DA.ReceivedDate, CBR.Date) BETWEEN -30 AND ISNULL(DATEDIFF(day, DA.ReceivedDate, DA.DisbursedDate), 60)) 

) 

select * from main 

where RowNumber = 1 --and Ever90 = 1

--and SSN = '915E4B2F51E180C728D3DEF7074DE8B0B298531C1E0DF5557BC754C40C7A1ACF93AAD124DC38E2A7BE7C96ECF45B7180F2AA79B25A27945D59C979C6D4839669'

 --and SSN_A = '915E4B2F51E180C728D3DEF7074DE8B0B298531C1E0DF5557BC754C40C7A1ACF93AAD124DC38E2A7BE7C96ECF45B7180F2AA79B25A27945D59C979C6D4839669'
