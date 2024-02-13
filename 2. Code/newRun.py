




# Example usage
server = 'reporting-db.nystartfinans.net'
database = 'reporting-db'
username = 'Andreas'
password = 'nCq8Sg@1lYnd(E'
path = "/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Behaviour-ScoreCard-DATA-223-/1. Data/1. BSD copy .sql"

print('Hello')

from Preprocessing_Application_N import DataPreprocessor


print('Hello')

# Initialize DataPreprocessor
processor = DataPreprocessor(server, database, username, password)

print('Hello')

# Fetch data from SQL script
df = processor.fetch_data_from_sql(path)

print("Script executed successfully.")













# print('hello')

# import pandas as pd
# import numpy as np
# import datetime
# import os




# ################### GET PAYMENT DATA ##########################


# server = 'reporting-db.nystartfinans.net'
# database = 'reporting-db'
# username = 'Andreas'
# password = 'nCq8Sg@1lYnd(E'

# path = "/Users/andreasnilsson/Library/CloudStorage/OneDrive-Nstart/Skrivbordet/Repository Homes/Behaviour-ScoreCard-DATA-223-/1. Data/1. BSD copy  copy.sql"


# import subprocess

# # Command to execute SQL script
# command = [
#     "sqlcmd",
#     "-S",
#     server,
#     "-d",
#     database,
#     "-U",
#     username,
#     "-P",
#     password,
#     "-i",
#     path
# ]

# # Execute command
# subprocess.run(command)

# print("Script executed successfully.")
