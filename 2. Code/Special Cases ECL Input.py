import os
import sys
import pandas as pd
import numpy as np
import datetime as dt
import sqlalchemy as sa
import pyodbc
import warnings
import urllib

# Suppress warnings if necessary
warnings.filterwarnings('ignore')

# Ensure that the path to custom modules is correct and add it to sys.path
path_to_classes = "./2. Code/Classes"
sys.path.append(os.path.abspath(path_to_classes))

# Import custom modules
from Credentials_Loader import CredentialLoader
from Preprocessing_Application_N import DataPreprocessor

# Initialize the CredentialLoader and load credentials
credential_loader = CredentialLoader()
credentials = credential_loader.load_credentials()  # Ensure this method exists and properly reads from a .env or similar file

# Retrieve credentials
username = credentials['username']
password = credentials['password']
server = credentials['server']
database = credentials['reporting_db']
driver = '{ODBC Driver 17 for SQL Server}'  # Adjust based on your database and installed ODBC driver


# Initialize the DataPreprocessor
processor = DataPreprocessor(server, database, username, password, driver)

# Set the path to the SQL file (ensure the path is correct relative to the current working directory)
path_to_sql = "1. Data/Skuldsannering.sql"

# Fetch data using the DataPreprocessor
df = processor.fetch_data_from_sql(path_to_sql)


print(max(df.DecisionDate))

UC_Accounts = df[df.AccountStatus.isin(['COLLECTION','FROZEN','OPEN'])]

UC_cleand = UC_Accounts[['AccountNumber','DisbursedDate','AccountStatus','EventTypeDesc','HasCoapp']]
UC_cleand['AccountNumber']  =  UC_cleand.AccountNumber.astype(int)
UC_cleand['Source']  = 'UC_Report'

UC_cleand = UC_cleand.drop_duplicates()



print(os.getcwd())

###############################  2  Import OLD VILJA ACCOUNTS THAT WE CANNOT SEE IN DB   ############################### 



relative_path_to_excel = "1. Data/Skuldsanneringsdata Excel/Vilja Skuldsannering gammal.xlsx"

df = pd.read_excel(relative_path_to_excel, sheet_name="Vilja Gammal", engine='openpyxl')

df.rename(columns={'Lånekonto':'AccountNumber'},inplace=True)

df['AccountNumber']  =  df.AccountNumber.astype(int)



###############################  Find if main/CO   - I denna är alla med oavsett om vi inte kan se  om både huvud/medsök har skuldsannering  ############################### 



path = "1. Data/ApplicationsALL.sql"

appli = processor.fetch_data_from_sql(path)

appli['AccountNumber']  =  appli.AccountNumber.astype(int)




oldfull = pd.merge(df, appli,on='AccountNumber',how='left' )

oldfull = oldfull[oldfull.AccountStatus.isin(['COLLECTION','FROZEN','OPEN'])]


old_cleand = oldfull[['AccountNumber','DisbursedDate','AccountStatus','HasCoapp']].drop_duplicates()

old_cleand['EventTypeDesc'] = 'Skuldsanering bevilj'
old_cleand['Source'] = 'Vilja Old'
old_cleand = old_cleand.drop_duplicates()


# Filter to include rows where AccountNumber in old_cleand is not in AccountNumber in UC_cleand
old_cleand = old_cleand[~old_cleand.AccountNumber.isin(UC_cleand.AccountNumber)]


collect = pd.concat([UC_cleand,old_cleand])
collect = collect.drop_duplicates()


collect['LGD'] = np.where(collect.EventTypeDesc == 'Skuldsanering bevilj',0.5,1)


# Get today's date
today = dt.date.today()

# Calculate the first day of the current month
first_day_of_current_month = dt.date(today.year, today.month, 1)

# Subtract one day from the first day of the current month to get the last day of the previous month
last_day_of_previous_month = first_day_of_current_month - dt.timedelta(days=1)

collect['ReportingDate'] = last_day_of_previous_month


collect = collect.drop_duplicates()
collect = collect.drop(columns=['HasCoapp','DisbursedDate','Source'])



# Update the driver to 'ODBC Driver 17 for SQL Server' for Native Client 17
# This assumes you're using ODBC Driver 17, which is the usual driver used with SQL Server Native Client 17 installations
engine = sa.create_engine(f'mssql+pyodbc://{username}:{password}@{server}:1433/{database}?driver=ODBC+Driver+17+for+SQL+Server')

# Upload DataFrame to SQL table
collect.to_sql('SpecialCases', con=engine, index=False, if_exists='append', schema='nystart')


# excel_file_path = 'SpecialCases_mars_see.xlsx'

# # Export the DataFrame to Excel
# collect.to_excel(excel_file_path, index=False)
