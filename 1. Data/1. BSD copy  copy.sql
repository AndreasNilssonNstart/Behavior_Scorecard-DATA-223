SELECT TOP 100 *
FROM nystart.LoanPortfolio
WHERE SnapshotDate > DATEADD(MONTH, -3, GETDATE())
