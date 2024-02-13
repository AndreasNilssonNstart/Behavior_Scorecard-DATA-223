




WITH DEL90 AS (
    SELECT DISTINCT 
    
    [AccountNumber] ,Ever90 ,DisbursedDate ,SnapshotDate ,mob , CurrentAmount
    
    --* --
    
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly]
    WHERE IsMonthEnd =1  --[SnapshotDate] <= DATEADD(MONTH, -12, GETDATE())   -- ScoreCard needs 12 Month on book mob = 12 and 
)   -- Expected 568 rows -- date of analysis 2023-08-22

SELECT * from DEL90 order by AccountNumber ,mob














-- Ta UCScore från Credit Report, ibland blir den null I Application 

-- WITH DEL90 AS (
--     SELECT DISTINCT [AccountNumber] ,Ever90 ,DisbursedDate ,SnapshotDate ,mob
    
--     FROM [Reporting-db].[nystart].[LoanPortfolioMonthly]
--     WHERE IsMonthEnd =1  --[SnapshotDate] <= DATEADD(MONTH, -12, GETDATE())   -- ScoreCard needs 12 Month on book mob = 12 and 
-- ),   -- Expected 568 rows -- date of analysis 2023-08-22




-- DEL90_Applications_MaxDate AS (
--     SELECT 
        
--         D.Ever90,
--         D.AccountNumber,
--         A.ApplicationID,
--         A.[SSN] as SSN_A,
--         A.[IsMainApplicant],
--         --A.[ApplicantNo],
--         A.[HasCoapp],      

--         A.[ReceivedDate],
--         A.[DisbursedDate],
--         A.[Amount],
--         A.[StartupFee],
--         --A.[UCScore],
--         A.ApplicationScore,
--         A.[PaymentRemarks],
--         A.[CreditOfficer],
--         A.[SalesChannel],
--         A.[Product],
--         A.[Migrated],
--         A.[BrokerName],
--         A.[OriginalSalesChannel],
--         A.[BirthDate],
--         A.[Bookingtype],
--         A.[MaritalStatus],
--         A.[EmploymentType],
--         A.[HousingType],
--         A.[MonthlySalary],   
--         A.[Referer],
--         A.[Campaign],
--         A.[SourceMedium],
--         A.[Keyword],
--         A.[NystartChannel],
--         A.[PNReceivedDate],
--         A.[NumberOfApplicants],
--         A.[Gender],
--         A.[CoappSameAddress],
--         A.[Kronofogden],
--         A.[CreditCardsNo],
--         A.[InstallmentLoansNo],
--         A.[UnsecuredLoansNo],
--         A.[LastPaymentRemarkDate] as LastPaymentRemarkDate1,
--         A.[TotalLoans],
--         A.[NystartBalance],
--         A.[TotalUnsecuredLoans]


--     FROM 
--         [Reporting-db].[nystart].[Applications] as A
--     INNER JOIN DEL90 D ON A.AccountNumber = D.AccountNumber  and A.DisbursedDate =  D.DisbursedDate

--     where IsMainApplicant = 1 and HasCoapp = 0  and A.[Status] = 'DISBURSED' 

--     -- GROUP BY D.AccountNumber , A.SSN, A.DisbursedDate ,A.Status

    
-- ),   -- Expected 568 rows --

--  main AS (

-- SELECT row_number() over (partition by AccountNumber,DA.SSN_A order by CBR.Date desc) as RowNumber

-- -- additional features


--    --,CBR.ssn     -- CBR.SSN  --DA.Status, CBR.*
    


    
--    ,DA.* 
--     ,CBR.[RiskPrognos] as UCScore
--    ,
--     CBR.[SSN],
--     CBR.[jsonID],
--     CBR.[Date],
--     CBR.[import_key],
--     CBR.[SSN2],
--      CBR.[Inquiries12M],
--     CBR.[CountyCode],
--     CBR.[MunicipalityCode],
--     CBR.[PostalCode],
--     CBR.[GuardianAppointed],
--     CBR.[BlockCode],
--     CBR.[BlockCodeDate],
--     CBR.[CivilStatus],
--     CBR.[CivilStatusDate],
--     CBR.[TimeOnAddress],
--     CBR.[AddressType],
--     CBR.[Country],
    
--     CBR.[IncomeYear],
--     CBR.[ActiveBusinessIncome],
--     CBR.[PassiveBusinessIncome],
--     CBR.[EmploymentIncome],
--     CBR.[CapitalIncome],
--     CBR.[CapitalDeficit],
--     CBR.[GeneralDeductions],
--     CBR.[ActiveBusinessDeficit],
--     CBR.[TotalIncome],
--     CBR.[IncomeYear2],
--     CBR.[ActiveBusinessIncome2],
--     CBR.[PassiveBusinessIncome2],
--     CBR.[EmploymentIncome2],
    
--     CBR.[CapitalIncome2],
--     CBR.[CapitalDeficit2],
--     CBR.[GeneralDeductions2],
--     CBR.[ActiveBusinessDeficit2],
--     CBR.[TotalIncome2],
--     CBR.[IncomeBeforeTax],
--     CBR.[IncomeBeforeTaxPrev],
--     CBR.[IncomeFromCapital],
--     CBR.[DeficitFromCapital],
--     CBR.[IncomeFromOwnBusiness],
--     CBR.[PaymentRemarksNo],
--     CBR.[PaymentRemarksAmount],
--     CBR.[LastPaymentRemarkDate],
--     CBR.[KFMPublicClaimsAmount],
--     CBR.[KFMPrivateClaimsAmount],
--     CBR.[KFMTotalAmount],
--     CBR.[KFMPublicClaimsNo],
--     CBR.[KFMPrivateClaimsNo],
--     CBR.[HouseTaxValue],
--     CBR.[HouseOwnershipPct],
--     CBR.[HouseOwnershipStatus],
--     CBR.[HouseOwnershipNo],
    
--     CBR.[BusinessInquiries],
--     CBR.[CreditCardsUtilizationRatio],
--     CBR.[HasMortgageLoan],
--     CBR.[HasCard],
--     CBR.[HasUnsecuredLoan],
--     CBR.[HasInstallmentLoan],
--     CBR.[IndebtednessRatio],
--     CBR.[AvgIndebtednessRatio12M],
--     CBR.[ActiveCreditAccounts],
--     CBR.[NewUnsecuredLoans12M],
--     CBR.[NewInstallmentLoans12M],
--     CBR.[NewCreditAccounts12M],
--     CBR.[NewMortgageLoans12M],
--     CBR.[TotalNewExMortgage12M],
--     CBR.[VolumeChange12MExMortgage],
--     CBR.[VolumeChange12MUnsecuredLoans],
--     CBR.[VolumeChange12MInstallmentLoans],
--     CBR.[VolumeChange12MCreditAccounts],
--     CBR.[VolumeChange12MMortgageLoans],
--     CBR.[AvgUtilizationRatio12M],
--     CBR.[VolumeUsed],
--     CBR.[NumberOfAccounts],
--     CBR.[NumberOfLenders],
--     CBR.[ApprovedCreditVolume],
--     CBR.[InstallmentLoansVolume],
--     CBR.[CreditAccountsVolume],
--     CBR.[UnsecuredLoansVolume],

--     CBR.[MortgageLoansHouseVolume],                     -- DENNA 

--     CBR.[MortgageLoansApartmentVolume],
    
--     CBR.[NumberOfCredits],
--     CBR.[NumberOfCreditors],
--     CBR.[ApprovedCardsLimit],
--     CBR.[NumberOfCreditCards],
--     CBR.[NumberOfBlancoLoans],
--     CBR.[SharedVolumeExMortgage],
--     CBR.[SharedVolume],
--     CBR.[NumberOfUnsecuredLoans],
--     CBR.[SharedVolumeUnsecuredLoans],
--     CBR.[NumberOfInstallmentLoans],
--     CBR.[SharedVolumeInstallmentLoans],
--     CBR.[NumberOfCreditAccounts],
--     CBR.[SharedVolumeCrerditAccounts],
--     CBR.[UtilizationRatio],
--     CBR.[CreditAccountOverdraft],
--     CBR.[NumberOfMortgageLoans],
--     CBR.[SharedVolumeMortgageLoans],
--     CBR.[SharedVolumeCreditCards]

-- FROM DEL90_Applications_MaxDate  as DA

-- LEFT JOIN [Reporting-db].[nystart].[CreditReportsBase] CBR ON CBR.SSN = DA.SSN_A  and (DATEDIFF(day, DA.ReceivedDate, CBR.Date) BETWEEN -30 AND ISNULL(DATEDIFF(day, DA.ReceivedDate, DA.DisbursedDate), 60)) 

-- ) 

-- select 

-- -- RiskPrognos,
-- -- UCScore,
-- -- ApplicationScore,
-- -- ReceivedDate,

-- * from main 

-- where RowNumber = 1      


-- --and ReceivedDate > '2022-07-01'    and ApplicationScore > 5   --and UCScore is null 


-- --and Ever90 = 1

-- --and SSN_A = '915E4B2F51E180C728D3DEF7074DE8B0B298531C1E0DF5557BC754C40C7A1ACF93AAD124DC38E2A7BE7C96ECF45B7180F2AA79B25A27945D59C979C6D4839669'