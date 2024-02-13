import pandas as pd
import numpy as np
import datetime
import os




################### GET PAYMENT DATA ##########################


from Preprocessing_Application import DataPreprocessor

server = 'reporting-db.nystartfinans.net'
database = 'reporting-db'
username = 'Andreas'
password = 'nCq8Sg@1lYnd(E'

path = "/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Behaviour-ScoreCard-DATA-223-/1. Data/1. BSD copy .sql"

preprocessor = DataPreprocessor(server, database, username, password) 

df = preprocessor.fetch_data_from_sql(path)





main = df[df.CoappFlag == 0]
co = df[df.CoappFlag == 1]

main = main[~main.AccountNumber.isin(co.AccountNumber)]
df = pd.concat([main,co])




#######################   CALCULATE BEHVAIOUR MODEL         ##################################


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


pd_ = pd_[['AccountNumber','AccountStatus','SnapshotDate',	'MOB'	,'DisbursedDate',	'CurrentAmount','RemainingTenor','CoappFlag',	'Ever30In6Months',	'WorstDelinquency6M','CurrentDelinquencyStatus','WorstDelinquency12M','Ever30In12Months','Ever90In12Months'	,'Score'	,'RiskClass','P','BehaviourModel','Ever90']]

BehaviourDone = pd_.copy()






#######################         CALCULATE ADMISSION MODEL         ##################################

path = '/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Admission-Scorecard-DATA-196/Codes'

# Change the current working directory
os.chdir(path)

from Preprocessing import DataPreprocessor


path = '/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Admission-Scorecard-DATA-196/DATA'


server = 'reporting-db.nystartfinans.net'
database = 'reporting-db'
username = 'Andreas'
password = 'nCq8Sg@1lYnd(E'

main_path = "/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Admission-Scorecard-DATA-196/DATA/MA Correct join - APL CRB-MLP Today.sql"
co_path = "/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Admission-Scorecard-DATA-196/DATA/CO Min score join - APL CBR MLP Today.sql"

preprocessor = DataPreprocessor(server, database, username, password)
final_df = preprocessor.process_data(main_path, co_path)


pd_ = final_df[['SSN','UCScore','age' ,'Inquiries12M','UtilizationRatio','Amount','MaritalStatus','ReceivedDate','DisbursedDate','Applicationtype','Ever90','Ever30','AccountNumber','CapitalDeficit','PropertyVolume','PaymentRemarks','IndebtednessRatio','ApplicationScore', 'StartupFee','PaymentRemarksNo'] ]







# Get the current date  to only include reporting month
now = datetime.datetime.now()

# Get the first day of the current month
first_day_of_month = datetime.datetime(now.year, now.month, 1)

# Filter the DataFrame for rows where 'DisbursedDate' is less than the first day of the current month
pd_ = pd_[pd_['DisbursedDate'] < first_day_of_month]






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


AdmissionDone = pd_[['AccountNumber','UCScore','age','Inquiries12M','PropertyVolume','AdmissionModel','ApplicationScore']]
AdmissionDone['AccountNumber'] = AdmissionDone['AccountNumber'].astype(int)





#######################         CREATE SICR LOGIC         ##################################


together = pd.merge(BehaviourDone,AdmissionDone , on='AccountNumber', how='outer')




## Only OPEN & FROZEN ACCOUNTS
lek = together[(together.AccountStatus.isin(['OPEN','FROZEN']) )& (together.SnapshotDate == max(together.SnapshotDate) )]


lek = together.copy()
lek = lek[(lek.AccountStatus.isin(['OPEN','FROZEN']) )]




lek['AppliedScore'] = np.where(  (lek.MOB < 3) & (lek.DisbursedDate > '2023-12-20') ,lek.AdmissionModel ,
                      np.where(  (lek.MOB < 3) & (lek.DisbursedDate <= '2023-12-20') ,lek.ApplicationScore/100 ,
                               
                               lek.BehaviourModel ))



lek['AppliedScore'] = np.where(  lek['AppliedScore'] > 0.744587 ,1.0 , lek['AppliedScore'])


lek['Stageing'] = np.where( lek.AppliedScore <=  0.248860, 'Stage1',
                    np.where( (lek.AppliedScore >  0.248860) & (lek.AppliedScore <=  0.744587), 'Stage2',
                        np.where( (lek.AppliedScore >  0.744587) , 'Stage3','CheCCHCH'
                                 
                        )))

## Apply a lifetime factor, this is based from UCBLANCO VINTAGE ANALYSIS, in lower risk but still high 20 % increase and on the rest it will be 10 % increase

lek['AppliedScore'] = np.where( (lek['Stageing'] == 'Stage2') &(lek['AppliedScore'] < 0.50) , lek.AppliedScore * 1.2 , 
                      np.where( (lek['Stageing'] == 'Stage2') &(lek['AppliedScore'] >= 0.50) , lek.AppliedScore * 1.1 ,   lek.AppliedScore )) ## Adding LifeTime Convertion to Stage 2 


lek['AppliedScore'] = np.where( lek.AppliedScore > 1,1,lek.AppliedScore)






###############  Get last months values   ###############



save = lek[(lek.SnapshotDate == max(lek.SnapshotDate))]

new = lek[(lek.SnapshotDate != max(lek.SnapshotDate))]
new = new[(new.SnapshotDate == max(new.SnapshotDate))]


new = new[['AccountNumber','AppliedScore','Stageing','SnapshotDate','Stage','CurrentAmount']]

vaR = (len(new.columns)-1)*(-1)

# Get the list of column names
columns = new.columns.tolist()

# Select the last two column names
last_two_columns = columns[vaR:]

# Create a dictionary that maps the old column names to the new ones with '_1m' suffix
rename_dict = {col: f"{col}_1m" for col in last_two_columns}

# Rename the last two columns
new_renamed = new.rename(columns=rename_dict)

see = pd.merge(  save, new_renamed , on='AccountNumber',how='outer')

see['PD_Delta'] = see.AppliedScore - see.AppliedScore_1m  

s1 = see[see.Stageing == 'Stage1']
s2 = see[see.Stageing == 'Stage2']

see['SICR'] = np.where(  ((see.Stageing_1m == 'Stage1'  ) & (see['PD_Delta'] > (np.max(s1.AppliedScore) - np.min(s1.AppliedScore)))   ) , 1,
                    
              np.where(    see.AppliedScore    >   0.744587   ,1,
              np.where(    see.Stageing != 'Stage1'   ,1, 
                    
                       0 )))               
                 

reporting = see[['AccountNumber','SnapshotDate','MOB','DisbursedDate','CurrentAmount','CurrentAmount_1m','AppliedScore','AppliedScore_1m','Stageing','Stageing_1m','PD_Delta','SICR']]



reporting.to_excel('test.xlsx', index=False)
