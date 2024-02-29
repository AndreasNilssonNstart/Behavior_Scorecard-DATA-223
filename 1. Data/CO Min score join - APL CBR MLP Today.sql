WITH
LPM_less12M_Accounts AS (
SELECT DISTINCT [AccountNumber]
     , max(mob) as max_mob               --,SnapshotDate
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly]
    WHERE  mob <= 12 and  IsMonthEnd = 1 --and AccountNumber = '7129596'
    GROUP by AccountNumber   ),

DEL90 AS (
    SELECT DISTINCT L.AccountNumber ,L.Ever90 ,L.DisbursedDate ,L.MOB      --,SnapshotDate
    FROM [Reporting-db].[nystart].[LoanPortfolioMonthly] as L
    inner join LPM_less12M_Accounts as A on L.AccountNumber =A.AccountNumber and L.MOB = A.max_mob ) ,


snn_score_both AS (
    SELECT

    
        A.AccountNumber,


        A.ApplicationID,
        A.[SSN] as SSN_A,
        A.ApplicationScore,
        A.[IsMainApplicant],
        --A.[ApplicantNo],
        A.[HasCoapp],      

        A.[ReceivedDate],
        A.[DisbursedDate],
        A.[Amount],
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
        A.[TotalUnsecuredLoans],
        A.PDScoreNew,

       -- CBR.[SSN],
    CBR.[jsonID],
    CBR.[Date],
    CBR.[import_key],
    CBR.[SSN2],
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
    CBR.[Inquiries12M],
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




    FROM [Reporting-db].[nystart].[Applications] as A
    INNER JOIN [Reporting-db].[nystart].[CreditReportsBase] CBR ON CBR.SSN = A.SSN
    WHERE
        A.HasCoapp = 1  
        and A.[Status] = 'DISBURSED' 
        AND (DATEDIFF(day, A.ReceivedDate, CBR.Date) BETWEEN -30 AND ISNULL(DATEDIFF(day, A.ReceivedDate, A.DisbursedDate), 60))
),

min_per_acc AS (
    SELECT 
        AccountNumber, 
        min(UCScore) as MinUCScore
    FROM snn_score_both  
    GROUP BY AccountNumber
),

numbered_scores AS (
    SELECT
        s.*,
        ROW_NUMBER() OVER(PARTITION BY s.AccountNumber ORDER BY s.UCScore DESC) AS RowNum
    FROM snn_score_both s
    INNER JOIN min_per_acc m ON m.AccountNumber = s.AccountNumber AND m.MinUCScore = s.UCScore
)

SELECT

        D.Ever90,

    s.*

FROM numbered_scores s

inner join DEL90 as d  on d.AccountNumber = s.AccountNumber


WHERE s.RowNum = 1 --and d.Ever90 = 1  --AND s.AccountNumber = 7739188
