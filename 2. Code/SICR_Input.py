import pandas as pd
import numpy as np
import datetime as dt
import os
import sqlalchemy as sa
import pyodbc
import warnings
warnings.filterwarnings('ignore')



################### GET PAYMENT DATA ##########################

path = "Classes"
os.chdir(path)

from Preprocessing_Application_N import DataPreprocessor



server = 'reporting-db.nystartfinans.net'
database = 'reporting-db'
username = 'Andreas'
password = 'nCq8Sg@1lYnd(E'
driver = '{ODBC Driver 17 for SQL Server}'  # This is an example for SQL Server, adjust according to your database and installed ODBC driver



engine = sa.create_engine('mssql+pyodbc://'+username+':'+password+'@'+server+':1433/'+database+'?driver=SQL+Server+Native+Client+11.0')

# Initialize DataPreprocessor with all required parameters, including the driver
processor = DataPreprocessor(server, database, username, password, driver)

path = "../../1. Data/Loan Portfolio Deli.sql"


df = processor.fetch_data_from_sql(path)



main = df[df.CoappFlag == 0]

co = df[df.CoappFlag == 1]

main = main[~main.AccountNumber.isin(co.AccountNumber)]

df = pd.concat([main,co])

df = df[df.AccountStatus.isin(['OPEN','FROZEN','COLLECTION'])]





################### IMPORT MACRO INSTRUMENT DATA ##########################


path = "../../1. Data"
os.chdir(path)

MacroInstrument = pd.read_excel('Macro_Instrument.xlsx')

#df.to_csv('BSC_Today.csv', index=False)

MacroInstrument = MacroInstrument[['Date','Instrument Rolling Mean']]
MacroInstrument['Instrument Rolling Mean'] = np.where(MacroInstrument['Instrument Rolling Mean'].notna(), MacroInstrument['Instrument Rolling Mean'],1 )    ## Will have 1 if NAN but this shall be updated each month 
MacroInstrument['Date'] =  MacroInstrument['Date'].astype(str)
MacroInstrument






#######################   CALCULATE BEHVAIOUR MODEL         ##################################
print('hej1')

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
calibration_coef = 9.82696528
calibration_intercept = -8.57437634


print("Coefficient:", calibration_coef)
print("Intercept:", calibration_intercept)

# Using the original probabilities to calibrate them with the calibration model
pd_['Z_calibrated'] = pd_['P'].apply(lambda x: x * calibration_coef + calibration_intercept)

# Compute the calibrated probabilities
pd_['BehaviourModel'] = pd_['Z_calibrated'].apply(lambda x: 1 / (1 + np.exp(-x)))


pd_ = pd_[['AccountNumber','AccountStatus','SnapshotDate',	'MOB'	,'DisbursedDate',	'CurrentAmount','RemainingTenor','CoappFlag',	'Ever30In6Months',	'WorstDelinquency6M','CurrentDelinquencyStatus','WorstDelinquency12M','Ever30In12Months','Ever90In12Months'	,'Score'	,'RiskClass','P','BehaviourModel','Ever90','ForberanceIn6Months','ForberanceIn12Months']]
pd_.loc[:, 'DisbursedDate'] = pd.to_datetime(pd_['DisbursedDate'])


BehaviourDone = pd_.copy()





print('hej2')
#######################         CALCULATE ADMISSION MODEL         ##################################

main_path = "../1. Data/MA Correct join - APL CRB-MLP Today.sql"
co_path = "../1. Data/CO Min score join - APL CBR MLP Today.sql"

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



print('hej3')


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

print(type(AdmissionDone['AccountNumber']))
print(type(BehaviourDone['AccountNumber']))


print('hej4')
#######################         CREATE SICR LOGIC         ##################################


AdmissionDone = pd_[['AccountNumber','PDScoreNew','UCScore','age','Inquiries12M','PropertyVolume','AdmissionModel','ApplicationScore']]
AdmissionDone['AccountNumber'] = AdmissionDone['AccountNumber'] # .astype(int)

together = pd.merge(BehaviourDone,AdmissionDone , on='AccountNumber', how='left')


## Only OPEN & FROZEN ACCOUNTS
lek = together[ (together.SnapshotDate == max(together.SnapshotDate) )]




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


see['FBE'] = np.where( (see.ForberanceIn12Months == 1) &  (see.CurrentDelinquencyStatus > 1) , 1,0)


see['SICR'] = np.where((see.PD_Delta > 0.0675) | (see['FBE'] == 1), 1, 0)



## Apply a lifetime factor, this is based from UCBLANCO VINTAGE ANALYSIS, in lower risk but still high 20 % increase and on the rest it will be 10 % increase

see['AdjustedBehaviourScore'] = np.where( (see['SICR'] == 1) &(see['AdjustedBehaviourScore'] < 0.50) , see.AdjustedBehaviourScore * 1.2 , 
                      np.where( (see['SICR'] == 1) &(see['AdjustedBehaviourScore'] >= 0.50) , see.AdjustedBehaviourScore * 1.1 ,   see.AdjustedBehaviourScore )) ## Adding LifeTime Convertion to Stage 2 


see['AdjustedBehaviourScore'] = np.where( see.AdjustedBehaviourScore > 1,1,see.AdjustedBehaviourScore)



see['Stageing'] = np.where(   (see['SICR'] == 0 ) 
                           
                           ,'Stage1',
                           np.where(   see['AdjustedBehaviourScore'] == 1.0 ,'Stage3','Stage2'))


see = see.drop_duplicates()


# Merge lek with MacroInstrument on 'SnapshotDate' in lek and 'Date' in MacroInstrument
see = pd.merge(see, MacroInstrument, left_on='SnapshotDate', right_on='Date', how='left')

see['AdjustedBehaviourScore'] =  see['BehaviourModel'] * see['Instrument Rolling Mean']

see['AdjustedBehaviourScore'] = np.where(  see['CurrentDelinquencyStatus'].isin([4,9]) ,1.0 , see['BehaviourModel'])


see.to_sql('ECLInput', con=engine, index=False, if_exists='replace', schema='nystart')
#path = "Code Export"
#os.chdir(path)

#see.to_excel('ECL_Input.xlsx')

