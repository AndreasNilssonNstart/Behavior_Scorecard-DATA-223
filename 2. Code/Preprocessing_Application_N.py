
import numpy as np
import pandas as pd
import pyodbc  # using pyodbc as the database connector

class DataPreprocessor:
    
    def __init__(self, server, database, username, password, driver):
        self.server = server
        self.database = database
        self.username = username
        self.password = password
        self.driver = driver  # Add a driver attribute, since pyodbc requires specifying the ODBC driver to use

    def _connect_to_db(self):
        # Construct the connection string
        conn_str = f'DRIVER={self.driver};SERVER={self.server};DATABASE={self.database};UID={self.username};PWD={self.password}'
        # Connect to the database using pyodbc
        self.conn = pyodbc.connect(conn_str)

    def fetch_data_from_sql(self, file_path):
        # Ensure the database connection is established
        self._connect_to_db()
        
        # Read the SQL script from the file
        with open(file_path, 'r') as file:
            sql_query = file.read()
        
        # Use pd.read_sql to execute the query and load the results into a DataFrame
        df = pd.read_sql(sql_query, con=self.conn)
        
        # Close the database connection
        self.conn.close()
        
        return df

    def drop_columns(self, df, columns_to_drop):
        # Drop specified columns from the DataFrame
        return df.drop(columns=columns_to_drop, errors='ignore')

    def _merge_dataframes(self, main, co):
        # Concatenate two DataFrames
        return pd.concat([main, co])



    def apply_transformations(self, main, co):


        # Get today's date without time
        today = pd.Timestamp('today').floor('D')
        
        main = main[~pd.isna(main.UCScore)].copy()

        main.loc[:, 'Applicationtype'] = 0

        co = co.copy()
        co['Applicationtype'] = np.where(
            (co['HasCoapp'] == 1) & (co['CoappSameAddress'] == 1), 1,
            np.where(
                (co['HasCoapp'] == 1) & (co['CoappSameAddress'] == 0), 2,
                np.nan  # Default value for other conditions
            )
        )


        df = self._merge_dataframes(main, co)


        df['ReceivedDate'] = pd.to_datetime(df['ReceivedDate'])
        df = df.sort_values(by='ReceivedDate')


        for now in range(len(df['ReceivedDate'])-1):

            if df['ReceivedDate'].iloc[now] > df['ReceivedDate'].iloc[now+1]:

                print('2')




        

        df['BirthDate'] = pd.to_datetime(df['BirthDate'])

        # Compute the age based solely on years
        df['age'] = today.year -  df['BirthDate'].dt.year

        # Adjust for cases where the birthdate hasn't occurred this year yet
        df['age'] = np.where((today.month < df['BirthDate'].dt.month) | 
                            ((today.month == df['BirthDate'].dt.month) & (today.day < df['BirthDate'].dt.day)), 
                            df['age']-1, 
                            df['age'])






        credit_data_columns = [
            'PaymentRemarksNo',
            'PaymentRemarksAmount',
            "CreditCardsNo",
            "ApprovedCardsLimit",
            "CreditAccountsVolume",
            "CapitalIncome",
            "PassiveBusinessIncome2",
            "CapitalIncome2",
            "ActiveBusinessDeficit2",
            "KFMPublicClaimsAmount",
            "KFMTotalAmount",
            'KFMPrivateClaimsAmount',   # Added the missing comma here
            "KFMPublicClaimsNo",
            "KFMPrivateClaimsNo",
            "HouseTaxValue",
            "MortgageLoansHouseVolume",
            'MortgageLoansApartmentVolume',
            'AvgUtilizationRatio12M',
            'EmploymentIncome',
            'EmploymentIncome2'

        ]

        
               

        # Ensure the specified columns are float and fill NaN with 0
        for column in credit_data_columns:
            if column in df.columns:  # Only apply to columns that exist in the dataframe
                df[column] = df[column].astype(float).fillna(0)




        loan_columns = [
            "InstallmentLoansNo",
            "IndebtednessRatio",
            "AvgIndebtednessRatio12M",
            "InstallmentLoansVolume",
            "VolumeChange12MExMortgage",
            "VolumeChange12MUnsecuredLoans",
            "VolumeChange12MInstallmentLoans",
            "VolumeChange12MCreditAccounts",
            "VolumeChange12MMortgageLoans",
            "AvgUtilizationRatio12M",
            "CreditCardsUtilizationRatio",
            "UnsecuredLoansVolume",
            "NumberOfLenders",
            "CapitalDeficit",
            "CapitalDeficit2",
            "NewUnsecuredLoans12M",
            "NewInstallmentLoans12M",
            "NewCreditAccounts12M",
            "VolumeUsed",
            "ApprovedCreditVolume"
            ,'NumberOfBlancoLoans'
            ,'NumberOfCreditCards'
            ,'NewMortgageLoans12M'
            ,	'TotalNewExMortgage12M'

            ,  "NumberOfMortgageLoans",
            "SharedVolumeMortgageLoans",
            "SharedVolumeCreditCards",
            "NumberOfUnsecuredLoans",
            "SharedVolumeUnsecuredLoans",
            "NumberOfInstallmentLoans",
            "SharedVolumeInstallmentLoans",
            "NumberOfCreditAccounts",
            "SharedVolumeCrerditAccounts"
            ,'UnsecuredLoansNo'
            , 'IncomeDelta_1Year'
            ,'kids_number'

            ,'Inquiries12M'

        ]



        # Ensure the specified columns are float and fill NaN with -1
        for column in loan_columns:
            if column in df.columns:  # Only apply to columns that exist in the dataframe
                df[column] = df[column].astype(float).fillna(-1)


        loan_columns = [
        "CapitalDeficit_Delta_1Year","UtilizationRatio",'housing_cost']



        # Ensure the specified columns are float and fill NaN with -1
        for column in loan_columns:
            if column in df.columns:  # Only apply to columns that exist in the dataframe
                df[column] = df[column].astype(float).fillna(-100)



        inf_columns = ['CapitalDeficit_Delta_1Year',
                    'IncomeDelta_1Year',
                    'ActiveCreditAccounts']
            
        for col in inf_columns:
            if col in df.columns:
                df[col] = df[col].replace([np.inf, -np.inf], -100)


        ## the rest

        for Cname in df.columns:

            if str(df[Cname].dtype) == 'object':
                df[Cname].fillna('Unknown', inplace=True)
                df[Cname].replace('None', 'Unknown', inplace=True)


        df['PropertyVolume'] = np.where( df.MortgageLoansHouseVolume > 0, df.MortgageLoansHouseVolume,
            np.where( df.MortgageLoansApartmentVolume > 0, df.MortgageLoansApartmentVolume, 0))


        return df

    def process_data(self, main_sql_file_path, co_sql_file_path):
        # Fetch data for 'main'
        main = self.fetch_data_from_sql(main_sql_file_path)
        if main is None:
            return None  # or handle the error as appropriate

        # Fetch data for 'co'
        co = self.fetch_data_from_sql(co_sql_file_path)
        if co is None:
            return None  # or handle the error as appropriate

        # Apply transformations on both main and co
        final_df = self.apply_transformations(main, co)

        return final_df