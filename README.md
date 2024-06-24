# Reservation Process

This document outlines the steps necessary for running the Reservation Process. All the scripts and data files are located in the `Behavior_Scorecard-DATA-223` directory.

## Steps to Follow:

### 1. Run Special Cases - A
Execute the script named `Special Cases - A` to initiate the process.

### 2. Run `SICR.py`
Run the `SICR.py` script. This Python script performs the IFRS9 Stage logic. It imports a SQL file containing customer payment data which is then used as input for the Behavior Score model.

### 3. Update Online Cost - Manual
For now, this step must be done manually:
1. Obtain the previous month's result from Jonas Griblund.
2. Update the following SQL query with the new data and run it:

```sql
INSERT INTO nystart.OnlineCost (YearMonth, Cost)
VALUES (202405, 2439619);
```

### 4. Invoices Not Paid (Logic could be automated)
Maximilian Strandberg will send a list of unpaid invoices. Follow these steps:

1. Place the file in the following path: `/1. Data/Invoice Not Paid - Manual Finance Input`.

2. Rename the file in the directory to match the new file name in the Notebook: `InvoiceNotPaid.ipynb`.

3. Update the file path in the notebook:

   From:
   ```python
   relative_path_to_excel = "../../1. Data/Invoice Not Paid - Manual Finance Input/InvNotPaid n2 2024-04-30.xlsx"

To:

```python

relative_path_to_excel = "../../1. Data/Invoice Not Paid - Manual Finance Input/InvNotPaid 2024-05-31.xlsx"
```


Run the entire notebook by selecting "Run All".


### 5. Run the Final ECL Code that Consolidates everything

 1. Data/ECL PROD 2405.sql

It will produce 3 outputs:

Look into the previous file: /Behavior_Scorecard-DATA-223/3. Excel Analysis/ECL Final Files/ECL 2405.xlsx

And do the same with the three SQL Outputs.

Here One Could Do a Control on the ECL per stage to verify that the Stageing logic etc has gone as it should.

If everything looks fine send it in the Monthly Close Slack Channel and save it in: /Behavior_Scorecard-DATA-223/3. Excel Analysis/ECL Final Files