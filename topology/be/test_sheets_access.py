"""
Test Google Sheets access
"""
import os
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

SPREADSHEET_ID = os.getenv('GOOGLE_SHEETS_SPREADSHEET_ID')
CREDENTIALS_PATH = os.getenv('GOOGLE_SHEETS_CREDENTIALS_PATH')

print(f"Testing access to spreadsheet: {SPREADSHEET_ID}")
print(f"Using credentials from: {CREDENTIALS_PATH}")

try:
    # Create credentials
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH,
        scopes=['https://www.googleapis.com/auth/spreadsheets']
    )
    
    # Build service
    service = build('sheets', 'v4', credentials=credentials)
    
    # Try to read spreadsheet metadata
    result = service.spreadsheets().get(spreadsheetId=SPREADSHEET_ID).execute()
    
    print("\nSuccess! Can access spreadsheet.")
    print(f"Spreadsheet title: {result.get('properties', {}).get('title', 'Unknown')}")
    print(f"Sheets: {[sheet['properties']['title'] for sheet in result.get('sheets', [])]}")
    
    # Try to read values from first sheet
    first_sheet = result.get('sheets', [])[0]['properties']['title']
    values = service.spreadsheets().values().get(
        spreadsheetId=SPREADSHEET_ID,
        range=f'{first_sheet}!A1:A10'
    ).execute()
    
    print(f"\nCan read from sheet '{first_sheet}'")
    print(f"Values: {values.get('values', [])}")
    
except HttpError as error:
    print(f"\nError: {error}")
    print(f"Error details: {error.error_details}")