
  

SELECT  DISTINCT --top (1000)


AccountNumber , SnapshotDate ,

InvoicedInterest,PaidInterest ,InvoicedFee ,PaidFee,


 InvoicedInterest-PaidInterest+InvoicedFee-PaidFee  as unpaied 


  FROM [reporting-db].[nystart].[LoanPortfolio]

    WHERE SnapshotDate > DATEADD(MONTH, -1, GETDATE())

          -- Ensure SnapshotDate is the last day of its month by checking if adding one day shifts to a new month
          AND DATEADD(DAY, 1, SnapshotDate) = DATEADD(MONTH, DATEDIFF(MONTH, 0, SnapshotDate) + 1, 0)

and AccountStatus not in ('CANCELLED','CLOSED','DECEASED','PRE_SETTLED','WRITTEN_OFF')

and InvoicedInterest-PaidInterest+InvoicedFee-PaidFee > 0

and AccountNumber = 5001201



-- Ja det tror jag man skulle kunna göra! Den enda jag gör är att ladda ner en detaljerad lista över obetalda avier så tidigt som möjligt första dagen varje månad. 

--Invoice not paid värdet får vi fram genom att subtrahera “Aviserad obetald amortering” från “Obetalt belopp”. Sedan aggregerar jag listan och rensar bort lån med 

--status “Closed”, “Deceased”, “Pre_settled” och “Written_off”



SELECT distinct *



  FROM [reporting-db].[nystart].[LoanPortfolio]

    WHERE AccountNumber = 5191382
    
    --SnapshotDate > DATEADD(MONTH, -1, GETDATE())

          -- Ensure SnapshotDate is the last day of its month by checking if adding one day shifts to a new month
    and DATEADD(DAY, 1, SnapshotDate) = DATEADD(MONTH, DATEDIFF(MONTH, 0, SnapshotDate) + 1, 0)

--and AccountStatus not in ('CANCELLED','CLOSED','DECEASED','PRE_SETTLED','WRITTEN_OFF')

--and InvoicedInterest-PaidInterest+InvoicedFee-PaidFee > 0


