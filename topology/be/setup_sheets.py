"""
Setup Google Sheets for Topology Backend
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

# Define sheet names and their headers
SHEETS_CONFIG = {
    'users': [
        'user_id', 'email', 'username', 'display_name', 'password_hash', 
        'age', 'gender', 'country', 'bio', 'interests', 'profile_photo', 
        'photos', 'location', 'status', 'account_type', 'is_verified',
        'created_at', 'updated_at'
    ],
    'friends': [
        'friendship_id', 'user_id', 'friend_id', 'status', 
        'created_at', 'updated_at', 'accepted_at', 'rejected_at'
    ],
    'chats': [
        'message_id', 'sender_id', 'receiver_id', 'content', 
        'is_read', 'read_at', 'created_at'
    ],
    'video_calls': [
        'call_id', 'caller_id', 'receiver_id', 'status', 
        'started_at', 'ended_at', 'duration', 'call_type', 'created_at'
    ],
    'store_items': [
        'item_id', 'name', 'description', 'price', 'category', 
        'stock', 'purchase_count', 'is_featured', 'is_limited', 
        'is_active', 'created_at', 'updated_at'
    ],
    'purchases': [
        'purchase_id', 'user_id', 'item_id', 'quantity', 
        'unit_price', 'total_price', 'status', 'created_at'
    ],
    'filters': [
        'filter_id', 'user_id', 'name', 'age_range', 'genders', 
        'countries', 'interests', 'languages', 'only_online', 
        'only_verified', 'is_active', 'created_at', 'updated_at'
    ]
}

def get_sheets_service():
    """Get Google Sheets service instance."""
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH,
        scopes=['https://www.googleapis.com/auth/spreadsheets']
    )
    
    service = build('sheets', 'v4', credentials=credentials)
    return service

def create_sheets():
    """Create all required sheets with headers."""
    service = get_sheets_service()
    
    # Get existing sheets
    try:
        spreadsheet = service.spreadsheets().get(
            spreadsheetId=SPREADSHEET_ID
        ).execute()
        
        existing_sheets = {
            sheet['properties']['title']: sheet['properties']['sheetId'] 
            for sheet in spreadsheet['sheets']
        }
        
        print(f"Found existing sheets: {list(existing_sheets.keys())}")
        
    except HttpError as error:
        print(f"Error accessing spreadsheet: {error}")
        return
    
    # Create missing sheets and add headers
    for sheet_name, headers in SHEETS_CONFIG.items():
        if sheet_name not in existing_sheets:
            # Create new sheet
            try:
                request = {
                    'addSheet': {
                        'properties': {
                            'title': sheet_name,
                            'gridProperties': {
                                'rowCount': 1000,
                                'columnCount': len(headers)
                            }
                        }
                    }
                }
                
                service.spreadsheets().batchUpdate(
                    spreadsheetId=SPREADSHEET_ID,
                    body={'requests': [request]}
                ).execute()
                
                print(f"Created sheet: {sheet_name}")
                
            except HttpError as error:
                print(f"Error creating sheet {sheet_name}: {error}")
                continue
        
        # Add headers to sheet
        try:
            range_name = f"{sheet_name}!A1:{chr(65 + len(headers) - 1)}1"
            
            service.spreadsheets().values().update(
                spreadsheetId=SPREADSHEET_ID,
                range=range_name,
                valueInputOption='RAW',
                body={'values': [headers]}
            ).execute()
            
            print(f"Added headers to sheet: {sheet_name}")
            
        except HttpError as error:
            print(f"Error adding headers to {sheet_name}: {error}")
    
    # Add some sample data
    add_sample_data(service)

def add_sample_data(service):
    """Add sample data to sheets."""
    # Sample store items
    store_items = [
        ['item-1', 'Premium Subscription - 1 Month', 'Get premium features for 1 month', 
         '9.99', 'premium', '999', '0', 'true', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-2', 'Premium Subscription - 3 Months', 'Get premium features for 3 months', 
         '24.99', 'premium', '999', '0', 'true', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-3', 'Premium Subscription - 1 Year', 'Get premium features for 1 year', 
         '79.99', 'premium', '999', '0', 'true', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-4', 'Super Like Pack - 5', 'Send 5 super likes', 
         '4.99', 'feature', '999', '0', 'false', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-5', 'Super Like Pack - 20', 'Send 20 super likes', 
         '14.99', 'feature', '999', '0', 'false', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-6', 'Boost - 30 minutes', 'Boost your profile for 30 minutes', 
         '2.99', 'boost', '999', '0', 'false', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
        ['item-7', 'Boost - 2 hours', 'Boost your profile for 2 hours', 
         '7.99', 'boost', '999', '0', 'false', 'false', 'true', 
         '2024-01-01T00:00:00Z', '2024-01-01T00:00:00Z'],
    ]
    
    try:
        # Check if store_items already has data
        result = service.spreadsheets().values().get(
            spreadsheetId=SPREADSHEET_ID,
            range='store_items!A2:A3'
        ).execute()
        
        if 'values' not in result or not result['values']:
            # Add store items
            service.spreadsheets().values().append(
                spreadsheetId=SPREADSHEET_ID,
                range='store_items!A2',
                valueInputOption='RAW',
                body={'values': store_items}
            ).execute()
            
            print("Added sample store items")
        else:
            print("Store items already have data")
            
    except HttpError as error:
        print(f"Error adding sample data: {error}")

if __name__ == '__main__':
    print("Setting up Google Sheets for Topology Backend...")
    print(f"Spreadsheet ID: {SPREADSHEET_ID}")
    print(f"Credentials Path: {CREDENTIALS_PATH}")
    
    create_sheets()
    
    print("\nSetup complete!")
    print("Make sure to share the spreadsheet with the service account email.")
    print("You can find the service account email in your credentials JSON file.")