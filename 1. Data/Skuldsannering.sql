-- Combining grund and grund2 for efficiency, assuming ssn_hash is needed for the join
WITH grund_combined AS (
    SELECT 
        g.InsertDate, 
        g.SSN, 
        g.EventTypeDesc, 
        g.DecisionDate,
        s.[ssn_hash]
    FROM 
        [reporting-db].[nystart].[UCCreditMonitoring] g
    LEFT JOIN 
        [Reporting-db].[nystartSecure].[SsnMap] s ON g.SSN = s.SSN
    WHERE 
        g.EventTypeDesc in  ('Skuldsanering bevilj','Personen har utvandr','Personen har avlidit') --    ,'Skuldsanering inledd' -- VÄntar med dessa
),

med AS (
    SELECT  
        a.[ApplicationID],
        a.[IsMainApplicant],
        a.[ApplicantNo],
        a.[HasCoapp],
        a.[ReceivedDate],
        a.[AccountNumber],
        a.[DisbursedDate],
        a.[Amount],
        g.*
    FROM 
        [Reporting-db].[nystart].[Applications] a
    RIGHT JOIN 
        grund_combined g ON a.SSN = g.ssn_hash
    WHERE 
        a.[Status] = 'DISBURSED'
),

status_code AS (
    SELECT 
        ApplicationID, 
        SUM(HasCoapp) AS both_SS 
    FROM 
        med
    GROUP BY 
        ApplicationID
),

accountstatus AS (
    SELECT 
        SnapshotDate, 
        AccountNumber, 
        AccountStatus
    FROM
        [Reporting-db].[nystart].[LoanPortfolio]
    WHERE
        SnapshotDate = (SELECT MAX(SnapshotDate) FROM [Reporting-db].[nystart].[LoanPortfolio])
)

SELECT DISTINCT
    m.*, 
    s.*, 
    a.AccountStatus
FROM 
    med m
INNER JOIN 
    status_code s ON m.ApplicationID = s.ApplicationID
INNER JOIN 
    accountstatus a ON a.AccountNumber = m.AccountNumber
WHERE 
    s.both_SS <> 1
ORDER BY 
    m.ApplicationID;

