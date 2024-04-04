


with apli as (

SELECT
    
      [IsMainApplicant]
      ,[ApplicantNo]
      ,[HasCoapp]
      ,[ReceivedDate]
     
      ,[AccountNumber]
      ,[DisbursedDate]
      ,[Amount]
      ,SSN

  FROM [Reporting-db].[nystart].[Applications]


  where [Status] = 'DISBURSED'
) 
,

accountstatus as ( 

SELECT
    SnapshotDate,
    AccountNumber,
    AccountStatus
FROM
    [Reporting-db].[nystart].[LoanPortfolio]
WHERE
    SnapshotDate = (SELECT MAX(SnapshotDate) FROM [Reporting-db].[nystart].[LoanPortfolio])

)


SELECT 

a.* 
,s.AccountStatus

from apli as a 
inner join accountstatus as s on a.AccountNumber = s.AccountNumber


--where a.AccountNumber = 5000526