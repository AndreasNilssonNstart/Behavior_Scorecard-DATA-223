



WITH LatestStatus AS (
    SELECT 
        AccountNumber, 
        MAX(StartDate) AS LastStartDate
    FROM 
        [Reporting-db].[nystart].[Forbearance]
    WHERE 
        ForbearanceName NOT IN ('Skip a pay', '')
    GROUP BY 
        AccountNumber
)
,

LatestForberanceStatus as (
SELECT f.AccountNumber, f.StartDate
FROM 
    [Reporting-db].[nystart].[Forbearance] AS f
INNER JOIN 
    LatestStatus AS l ON f.AccountNumber = l.AccountNumber AND f.StartDate = l.LastStartDate
WHERE 
    f.ForbearanceName NOT IN ('Skip a pay', '')

)

SELECT * from LatestForberanceStatus




