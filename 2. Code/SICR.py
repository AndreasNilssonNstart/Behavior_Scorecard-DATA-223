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

# Print the database name to verify successful credential loading
print(database)

# Initialize the DataPreprocessor
processor = DataPreprocessor(server, database, username, password, driver)

# Print the current working directory for debugging
print("Current Working Directory:", os.getcwd())

# Set the path to the SQL file (ensure the path is correct relative to the current working directory)
path_to_sql = "1. Data/Loan Portfolio Deli v2.sql"

# Fetch data using the DataPreprocessor
df = processor.fetch_data_from_sql(path_to_sql)


## almost never happnens 
df['CoappFlag'] = np.where((df['CoappFlag'] != 0) & (df['CoappFlag'] != 1) | (df['CoappFlag'].isna()), 0,  df['CoappFlag'])

main = df[df.CoappFlag == 0]

co = df[df.CoappFlag == 1]

main = main[~main.AccountNumber.isin(co.AccountNumber)]

df = pd.concat([main,co])

df = df[df.AccountStatus.isin(['OPEN','FROZEN','COLLECTION'])]


## The co - applicant data can make duplicates make sure the forbreance data does not become duplicated

FBE_ = df[df.FBE_eftergift == 1]
FBE_no = df[df.FBE_eftergift == 0]

# Step 2: Remove rows from FBE_no that have identical 'SnapshotDate' and 'AccountNumber' in FBE_
# Create a Boolean Series to identify rows to keep in FBE_no
mask = ~FBE_no[['SnapshotDate', 'AccountNumber']].apply(tuple, 1).isin(FBE_[['SnapshotDate', 'AccountNumber']].apply(tuple, 1))
# Apply the mask to filter FBE_no
FBE_no_filtered = FBE_no[mask]

# Step 3: Concatenate FBE_ and FBE_no_filtered into a new DataFrame
df = pd.concat([FBE_, FBE_no_filtered])


################### IMPORT MACRO INSTRUMENT DATA ##########################


path = "1. Data"
os.chdir(path)

MacroInstrument = pd.read_excel('Macro_Instrument.xlsx')

#df.to_csv('BSC_Today.csv', index=False)

MacroInstrument = MacroInstrument[['Date','Instrument Rolling Mean']]
MacroInstrument['Instrument Rolling Mean'] = np.where(MacroInstrument['Instrument Rolling Mean'].notna(), MacroInstrument['Instrument Rolling Mean'],1 )    ## Will have 1 if NAN but this shall be updated each month 
MacroInstrument['SnapshotDate'] =  pd.to_datetime(MacroInstrument['Date'])




#######################   CALCULATE BEHVAIOUR MODEL         ##################################
print('CALCULATE BEHVAIOUR MODEL')

coefficients = np.array([-0.44414603,  0.18778622 , 0.3539554 ,  0.70178643])
intercept = np.array([0])


# Sample DataFrame (Assuming you already have this in place)
pd_ = df.copy()


# Compute the Z values using your logistic regression model
pd_['Z'] = (pd_.CoappFlag * coefficients[0] +
            pd_.Ever30In6Months * coefficients[1] + 
            pd_.WorstDelinquency6M * coefficients[2] +
            pd_.CurrentDelinquencyStatus * coefficients[3] +

            intercept[0]) 

# Compute the original probabilities
pd_['P'] = pd_['Z'].apply(lambda x: 1 / (1 + np.exp(-x)))

# Coefficients and Intercept from the Calibration model
calibration_coef = 10.11569562
calibration_intercept = -8.18226514


print("Coefficient:", calibration_coef)
print("Intercept:", calibration_intercept)

# Using the original probabilities to calibrate them with the calibration model
pd_['Z_calibrated'] = pd_['P'].apply(lambda x: x * calibration_coef + calibration_intercept)

# Compute the calibrated probabilities
pd_['BehaviourModel'] = pd_['Z_calibrated'].apply(lambda x: 1 / (1 + np.exp(-x)))


pd_ = pd_[['AccountNumber','AccountStatus','SnapshotDate',	'MOB'	,'DisbursedDate',	'CurrentAmount','RemainingTenor','CoappFlag',
'Ever30In6Months',	'WorstDelinquency6M','CurrentDelinquencyStatus',
'WorstDelinquency12M','Ever30In12Months','Ever90In12Months'	,'P','BehaviourModel','Ever90',
'ForberanceIn6Months','ForberanceIn12Months','FBE_eftergift']] ## 'Score'	,'RiskClass', Had these before to controll results (OLD BEHAVIOUR MODEL)

pd_.loc[:, 'DisbursedDate'] = pd.to_datetime(pd_['DisbursedDate'])


BehaviourDone = pd_.copy()


print('BehaviourDone Done')


print(os.getcwd())


#######################         CALCULATE ADMISSION MODEL         ##################################

main_path = "MA Correct join - APL CRB-MLP Today.sql"
co_path = "CO Min score join - APL CBR MLP Today.sql"

preprocessor = DataPreprocessor(server, database, username, password,driver)
final_df = preprocessor.process_data(main_path, co_path)


pd_ = final_df[['SSN','PDScoreNew','UCScore','age' ,'Inquiries12M','UtilizationRatio','Amount','MaritalStatus','ReceivedDate','DisbursedDate','Applicationtype','Ever90',
                'Ever30',
                'AccountNumber','CapitalDeficit','PropertyVolume','PaymentRemarks','IndebtednessRatio','ApplicationScore', 'StartupFee','PaymentRemarksNo'] ]





# Assuming pd_ is your DataFrame and it's already defined

# Get the current date
now = dt.datetime.now()

# Get the first day of the current month
first_day_of_month = dt.datetime(now.year, now.month, 1)

# Ensure 'DisbursedDate' is in datetime format if it's not already
pd_.loc[:, 'DisbursedDate'] = pd.to_datetime(pd_['DisbursedDate'])


# Filter the DataFrame for rows where 'DisbursedDate' is less than the first day of the current month
pd_ = pd_[pd_['DisbursedDate'] < first_day_of_month]

# Print the maximum 'DisbursedDate' from the filtered DataFrame
print(pd_['DisbursedDate'].max())





# Coefficients and Intercept from the Logistic Regression model
coefficients = np.array([2.03675292e+00 ,-2.18071234e-02  ,3.39715771e-02, -2.12322589e-07])  
intercept = np.array([-0.13407141])

print("Coefficients:", coefficients)
print("Intercept:", intercept)


# Compute the Z values using your logistic regression model
pd_['Z'] = (pd_.UCScore * coefficients[0] +
            pd_.age * coefficients[1] + 
            pd_.Inquiries12M * coefficients[2] +
            pd_.PropertyVolume * coefficients[3] + 
            intercept[0]) 

# Compute the original probabilities
pd_['P'] = pd_['Z'].apply(lambda x: 1 / (1 + np.exp(-x)))

# Coefficients and Intercept from the Calibration model
calibration_coef = 3.7812065422080856
calibration_intercept = -4.336067082588543




# Using the original probabilities to calibrate them with the calibration model
pd_['Z_calibrated'] = pd_['P'].apply(lambda x: x * calibration_coef + calibration_intercept)

# Compute the calibrated probabilities
pd_['AdmissionModel'] = pd_['Z_calibrated'].apply(lambda x: 1 / (1 + np.exp(-x)))


AdmissionDone = pd_[['AccountNumber','PDScoreNew','UCScore','age','Inquiries12M','PropertyVolume','AdmissionModel','ApplicationScore']]
AdmissionDone['AccountNumber'] = AdmissionDone['AccountNumber'] #.astype(int)

print('AdmissionDone')

# #######################         CREATE SICR LOGIC         ##################################


AdmissionDone = pd_[['AccountNumber','PDScoreNew','UCScore','age','Inquiries12M','PropertyVolume','AdmissionModel','ApplicationScore']]
AdmissionDone['AccountNumber'] = AdmissionDone['AccountNumber'] # .astype(int)

together = pd.merge(BehaviourDone,AdmissionDone , on='AccountNumber', how='left')


## Only OPEN & FROZEN ACCOUNTS
lek = together[ (together.SnapshotDate >= min(together.SnapshotDate) )]



# Ensure DisbursedDate is a datetime object (if not already)
lek['DisbursedDate'] = pd.to_datetime(lek['DisbursedDate'])

# Convert the string to a datetime object
comparison_date = pd.to_datetime('2023-12-20')



lek['AppliedApplicationScore'] = np.where(
    (lek['DisbursedDate'] > comparison_date) &
    (np.round(lek['PDScoreNew'], 2) <= np.round(lek['AdmissionModel'], 2)) &
    (lek['PDScoreNew'].notna()), 
    lek['PDScoreNew'],  

    np.where(
        (lek['DisbursedDate'] > comparison_date) &
        
        lek['PDScoreNew'].isna(),  
        lek['AdmissionModel'],  

        np.where(
            (lek['DisbursedDate'] <= comparison_date), 
            lek['ApplicationScore'] / 100,  
            lek['AdmissionModel'] 
        )
    )
)

lek['AdjustedBehaviourScore'] = np.where(  lek['CurrentDelinquencyStatus'].isin([4,9]) ,1.0 , lek['BehaviourModel'])






see = lek.copy()


see['AppliedApplicationScore'] = np.where(  see.AppliedApplicationScore.isna()   ,0 , see.AppliedApplicationScore )


see['PD_Delta'] = see.AdjustedBehaviourScore - see.AppliedApplicationScore 


see = see[see.MOB.notna()]   ## take away accounts that was closed last month

see['PD_Delta'] = np.where(see['PD_Delta'].isna() , 0,see['PD_Delta'])

see = see.sort_values(by='PD_Delta')



see['FBE'] = np.where(
    (see['ForberanceIn12Months'] == 1) & (see['CurrentDelinquencyStatus'] > 1) & (see['CurrentDelinquencyStatus'] < 4),
    'monitoring_previous_S3',
    np.where(
        see['FBE_eftergift'] == 1,
        'monitoring_paymentrelief',
        ''
    )
)


see['SICR'] = np.where((see.PD_Delta > 0.09) | (see['FBE'] != ''), 1, 0)



## Apply a lifetime factor, this is based from UCBLANCO VINTAGE ANALYSIS, in lower risk but still high 20 % increase and on the rest it will be 10 % increase

see['AdjustedBehaviourScore'] = np.where( (see['SICR'] == 1) &(see['AdjustedBehaviourScore'] < 0.50) , see.AdjustedBehaviourScore * 1.2 , 
                      np.where( (see['SICR'] == 1) &(see['AdjustedBehaviourScore'] >= 0.50) , see.AdjustedBehaviourScore * 1.1 ,   see.AdjustedBehaviourScore )) ## Adding LifeTime Convertion to Stage 2 


see['AdjustedBehaviourScore'] = np.where( see.AdjustedBehaviourScore > 1,1,see.AdjustedBehaviourScore)



see['Stageing'] = np.where(   (see['SICR'] == 0 ) 
                           
                           ,1,
                           np.where(   see['AdjustedBehaviourScore'] == 1.0 ,3,2))


see = see.drop_duplicates()
see['SnapshotDate'] = pd.to_datetime(see['SnapshotDate'])

# Merge lek with MacroInstrument on 'SnapshotDate' in lek and 'Date' in MacroInstrument
see = pd.merge(see, MacroInstrument, on='SnapshotDate', how='left')

see['AdjustedBehaviourScore'] =  see['BehaviourModel'] * see['Instrument Rolling Mean']

see['AdjustedBehaviourScore'] = np.where(  see['CurrentDelinquencyStatus'].isin([4,9]) ,1.0 , see['BehaviourModel'])


output = see[['AccountNumber','SnapshotDate','MOB','AppliedApplicationScore','AdjustedBehaviourScore','PD_Delta'	,'FBE','SICR','Stageing']]


# Update the driver to 'ODBC Driver 17 for SQL Server' for Native Client 17
# This assumes you're using ODBC Driver 17, which is the usual driver used with SQL Server Native Client 17 installations
engine = sa.create_engine(f'mssql+pyodbc://{username}:{password}@{server}:1433/{database}?driver=ODBC+Driver+17+for+SQL+Server')

# Upload DataFrame to SQL table
output.to_sql('CustomerScores', con=engine, index=False, if_exists='append', schema='nystart')

#path = "Code Export"
#os.chdir(path)

#see.to_excel('ECL_Input.xlsx')

print('Code Done')