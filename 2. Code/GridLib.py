import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from itertools import product

from joblib import Parallel, delayed


class GridSearchCustom:
    
    def __init__(self, model, param_grid):
        self.model = model
        self.param_grid = param_grid
        self.results = {}
    
    def compute_metrics(self, y_true, y_pred):
        return {
            'accuracy': accuracy_score(y_true, y_pred),
            'precision': precision_score(y_true, y_pred),
            'recall': recall_score(y_true, y_pred),
            'f1': f1_score(y_true, y_pred)
        }
    
    def fit(self, Xtrain, Ytrain, Xtest, Ytest):
        results_list = Parallel(n_jobs=-1)(delayed(self._train_and_evaluate)(params, Xtrain, Ytrain, Xtest, Ytest) for params in self._generate_param_combinations())
        
        for res in results_list:
            self.results.update(res)

    def _generate_param_combinations(self):
        for values in product(*self.param_grid.values()):
            params = dict(zip(self.param_grid.keys(), values))
            yield params

    def _train_and_evaluate(self, params, Xtrain, Ytrain, Xtest, Ytest):
        model_instance = self.model(**params)
        model_instance.fit(Xtrain, Ytrain)
        
        y_train_pred = model_instance.predict(Xtrain)
        y_test_pred = model_instance.predict(Xtest)
        
        return {
            str(params): {
                'train': self.compute_metrics(Ytrain, y_train_pred),
                'test': self.compute_metrics(Ytest, y_test_pred)
            }
        }
    
    def to_dataframe(self):
        df_list = []
        
        for params, metrics in self.results.items():
            row = eval(params)
            
            for dataset, metric_values in metrics.items():
                for metric, value in metric_values.items():
                    col_name = f"{dataset}_{metric}"  # e.g., 'train_accuracy', 'test_precision', etc.
                    row[col_name] = value
            df_list.append(row)

        df = pd.DataFrame(df_list)
        
        # List of metrics
        metrics = ['accuracy', 'precision', 'recall', 'f1']

        # Compute the Euclidean distance between train and test metrics for each row
        df['metric_distance'] = df.apply(lambda row: np.sqrt(sum([(row[f'train_{metric}'] - row[f'test_{metric}'])**2 for metric in metrics])), axis=1)

        return df
    
    def filter_by_precision(self):
        # Ensure the results have been stored in a DataFrame
        if not hasattr(self, 'results_df'):
            self.results_df = self.to_dataframe()

        # Filter based on test_precision
        precisions = self.results_df.sort_values(by='test_precision').tail(3000)

        # Normalize the values
        min_metric_distance = precisions['metric_distance'].min()
        max_metric_distance = precisions['metric_distance'].max()

        min_test_f1 = precisions['test_f1'].min()
        max_test_f1 = precisions['test_f1'].max()

        min_train_accuracy = precisions['train_accuracy'].min()
        max_train_accuracy = precisions['train_accuracy'].max()

        # Calculate the normalized values
        normalized_metric_distance = (precisions['metric_distance'] - min_metric_distance) / (max_metric_distance - min_metric_distance)
        normalized_test_f1 = (precisions['test_f1'] - min_test_f1) / (max_test_f1 - min_test_f1)
        normalized_train_accuracy = (precisions['train_accuracy'] - min_train_accuracy) / (max_train_accuracy - min_train_accuracy)

        # Compute the objective - I want optimize precision, stabalize train/val and have the best poosible train model (accurancy)
        precisions['objective'] = ((( 1 - normalized_metric_distance)*0.5 ) + (normalized_test_f1*1.0) + (normalized_train_accuracy*0.5)) / 3

        top_precisions = precisions.sort_values(by='objective').tail(1000)

        # Extract best parameters
        best_params = top_precisions.iloc[-1].drop(['train_accuracy', 'train_precision', 'train_recall', 'train_f1', 
                                                    'test_accuracy', 'test_precision', 'test_recall', 'test_f1', 
                                                    'metric_distance', 'objective'])

        return top_precisions, best_params.to_dict()






#     import numpy as np
# import pandas as pd
# from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
# from itertools import product

# from joblib import Parallel, delayed


# class GridSearchCustom:
    
#     def __init__(self, model, param_grid):
#         self.model = model
#         self.param_grid = param_grid
#         self.results = {}
    
#     def compute_metrics(self, y_true, y_pred):
#         return {
#             'accuracy': accuracy_score(y_true, y_pred),
#             'precision': precision_score(y_true, y_pred),
#             'recall': recall_score(y_true, y_pred),
#             'f1': f1_score(y_true, y_pred)
#         }
    
#     def fit(self, Xtrain, Ytrain, Xtest, Ytest):
#         for values in product(*self.param_grid.values()):
#             params = dict(zip(self.param_grid.keys(), values))
            
#             model_instance = self.model(**params)
#             model_instance.fit(Xtrain, Ytrain)
            
#             y_train_pred = model_instance.predict(Xtrain)
#             y_test_pred = model_instance.predict(Xtest)
            
#             self.results[str(params)] = {
#                 'train': self.compute_metrics(Ytrain, y_train_pred),
#                 'test': self.compute_metrics(Ytest, y_test_pred)
#             }
    
#     def to_dataframe(self):
#         df_list = []
        
#         for params, metrics in self.results.items():
#             row = eval(params)
            
#             for dataset, metric_values in metrics.items():
#                 for metric, value in metric_values.items():
#                     col_name = f"{dataset}_{metric}"  # e.g., 'train_accuracy', 'test_precision', etc.
#                     row[col_name] = value
#             df_list.append(row)

#         df = pd.DataFrame(df_list)
        
#         # List of metrics
#         metrics = ['accuracy', 'precision', 'recall', 'f1']

#         # Compute the Euclidean distance between train and test metrics for each row
#         df['metric_distance'] = df.apply(lambda row: np.sqrt(sum([(row[f'train_{metric}'] - row[f'test_{metric}'])**2 for metric in metrics])), axis=1)

#         return df