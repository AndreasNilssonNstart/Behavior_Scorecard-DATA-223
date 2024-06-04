import os

class CredentialLoader:
    def __init__(self, base_folder='Desktop', folder_name='L'):
        """
        Initialize the CredentialLoader with paths to the .env file.
        Cross-platform compatibility by checking the appropriate environment variable for the user's home directory.
        :param base_folder: The name of the base folder, defaults to 'Desktop'.
        :param folder_name: The name of the folder containing the .env file.
        """
        home_path = os.environ.get('HOME') or os.environ.get('USERPROFILE')  # Supports both Unix and Windows
        self.desktop_path = os.path.join(home_path, base_folder)
        self.folder_path = os.path.join(self.desktop_path, folder_name)
        self.env_file_path = os.path.join(self.folder_path, '.env')

    def load_credentials(self):
        """
        Load credentials from a .env file specified by the env_file_path.
        :return: A dictionary containing credentials.
        """
        credentials = {}
        try:
            with open(self.env_file_path, 'r') as file:
                for line in file:
                    key, value = line.strip().split('=')
                    credentials[key] = value
        except FileNotFoundError:
            print(f"Error: The file {self.env_file_path} was not found.")
        except Exception as e:
            print(f"An error occurred: {e}")
        return credentials

# # Example usage:
# if __name__ == "__main__":
#     loader = CredentialLoader()  # Initializes the loader with default paths
#     creds = loader.load_credentials()  # Loads the credentials from .env
#     print(creds)
