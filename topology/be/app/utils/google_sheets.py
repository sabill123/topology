"""
Google Sheets database manager
"""
import os
import json
from typing import List, Dict, Any, Optional
from datetime import datetime
from google.oauth2.credentials import Credentials
from google.oauth2.service_account import Credentials as ServiceAccountCredentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
import hashlib
from uuid import uuid4
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class GoogleSheetsManager:
    """Manager for Google Sheets operations"""
    
    _instance = None
    _service = None
    
    # Spreadsheet structure from environment
    SPREADSHEET_ID = os.getenv('GOOGLE_SHEETS_SPREADSHEET_ID', "1wCMvtnEqtsJdNFIgkQMNkQCGT_eiAgRDcknprwPCzhI")
    SHEETS = {
        "users": "users",
        "friends": "friends",
        "chats": "chats",
        "video_calls": "video_calls",
        "store_items": "store_items",
        "purchases": "purchases",
        "filters": "filters"
    }
    
    # Column mappings
    USER_COLUMNS = [
        "id", "email", "username", "display_name", "hashed_password",
        "age", "gender", "country", "bio", "profile_image_url",
        "preferred_gender", "preferred_age_min", "preferred_age_max",
        "is_profile_public", "allow_random_calls", "role", "gems",
        "status", "last_seen", "created_at", "updated_at",
        "is_active", "is_verified"
    ]
    
    @classmethod
    def initialize(cls):
        """Initialize Google Sheets connection"""
        if cls._instance is None:
            cls._instance = cls()
            cls._instance._connect()
    
    @classmethod
    def get_instance(cls):
        """Get singleton instance"""
        if cls._instance is None:
            cls.initialize()
        return cls._instance
    
    def _connect(self):
        """Connect to Google Sheets API"""
        try:
            # Load credentials from environment or file
            creds = None
            credentials_path = os.getenv('GOOGLE_SHEETS_CREDENTIALS_PATH')
            
            # Try to load from environment variable path
            if credentials_path and os.path.exists(credentials_path):
                creds = ServiceAccountCredentials.from_service_account_file(
                    credentials_path,
                    scopes=['https://www.googleapis.com/auth/spreadsheets']
                )
            # Try to load from environment variable
            elif os.environ.get('GOOGLE_SHEETS_CREDENTIALS'):
                creds_json = json.loads(os.environ.get('GOOGLE_SHEETS_CREDENTIALS'))
                creds = ServiceAccountCredentials.from_service_account_info(
                    creds_json,
                    scopes=['https://www.googleapis.com/auth/spreadsheets']
                )
            # Or load from default file
            elif os.path.exists('credentials.json'):
                creds = ServiceAccountCredentials.from_service_account_file(
                    'credentials.json',
                    scopes=['https://www.googleapis.com/auth/spreadsheets']
                )
            else:
                raise Exception("No Google Sheets credentials found")
            
            self._service = build('sheets', 'v4', credentials=creds)
            print(f"Connected to Google Sheets: {self.SPREADSHEET_ID}")
            
        except Exception as e:
            print(f"Error connecting to Google Sheets: {e}")
            raise
    
    def _get_sheet_data(self, sheet_name: str, range_: str = None) -> List[List[Any]]:
        """Get data from a sheet"""
        try:
            if range_ is None:
                range_ = f"{sheet_name}!A:Z"
            else:
                range_ = f"{sheet_name}!{range_}"
                
            result = self._service.spreadsheets().values().get(
                spreadsheetId=self.SPREADSHEET_ID,
                range=range_
            ).execute()
            
            return result.get('values', [])
            
        except HttpError as e:
            print(f"Error reading sheet {sheet_name}: {e}")
            return []
    
    def _update_sheet_data(self, sheet_name: str, range_: str, values: List[List[Any]]):
        """Update data in a sheet"""
        try:
            body = {'values': values}
            
            self._service.spreadsheets().values().update(
                spreadsheetId=self.SPREADSHEET_ID,
                range=f"{sheet_name}!{range_}",
                valueInputOption='RAW',
                body=body
            ).execute()
            
        except HttpError as e:
            print(f"Error updating sheet {sheet_name}: {e}")
            raise
    
    def _append_to_sheet(self, sheet_name: str, values: List[List[Any]]):
        """Append data to a sheet"""
        try:
            body = {'values': values}
            
            self._service.spreadsheets().values().append(
                spreadsheetId=self.SPREADSHEET_ID,
                range=f"{sheet_name}!A:Z",
                valueInputOption='RAW',
                body=body
            ).execute()
            
        except HttpError as e:
            print(f"Error appending to sheet {sheet_name}: {e}")
            raise
    
    # User operations
    async def create_user(self, user_data: dict) -> dict:
        """Create a new user"""
        try:
            print(f"GoogleSheetsManager.create_user called with: {user_data.keys()}")
            
            # Generate user ID
            user_id = str(uuid4())
            now = datetime.utcnow().isoformat()
            
            # Use hashed_password from auth.py
            hashed_password = user_data.get('hashed_password', '')
            
            # Prepare row data
            row_data = [
                user_id,
                user_data.get('email'),
                user_data.get('username'),
                user_data.get('display_name'),
                hashed_password,
                user_data.get('age'),
                user_data.get('gender').value if hasattr(user_data.get('gender'), 'value') else str(user_data.get('gender', '')),  # Convert enum to string properly
                user_data.get('country'),
                user_data.get('bio', ''),
                user_data.get('profile_image_url', ''),
                user_data.get('preferred_gender', ''),
                user_data.get('preferred_age_min', 18),
                user_data.get('preferred_age_max', 100),
                user_data.get('is_profile_public', True),
                user_data.get('allow_random_calls', True),
                'user',  # role
                0,  # gems
                'offline',  # status
                now,  # last_seen
                now,  # created_at
                now,  # updated_at
                True,  # is_active
                False  # is_verified
            ]
            
            print(f"Row data prepared: {row_data[:5]}...")  # Print first 5 fields
            
            # Append to sheet
            self._append_to_sheet(self.SHEETS['users'], [row_data])
            print("Data appended to sheet")
            
            # Return created user
            created_user = self._row_to_user_dict(row_data)
            print(f"User dict created: {created_user.get('id')}")
            return created_user
            
        except Exception as e:
            print(f"Error creating user: {e}")
            import traceback
            traceback.print_exc()
            raise
    
    async def get_user_by_email(self, email: str) -> Optional[dict]:
        """Get user by email"""
        try:
            data = self._get_sheet_data(self.SHEETS['users'])
            
            if len(data) < 2:  # No data rows
                return None
                
            for row in data[1:]:  # Skip header
                if len(row) > 1 and row[1] == email:
                    return self._row_to_user_dict(row)
                    
            return None
            
        except Exception as e:
            print(f"Error getting user by email: {e}")
            return None
    
    async def get_user_by_id(self, user_id: str) -> Optional[dict]:
        """Get user by ID"""
        try:
            data = self._get_sheet_data(self.SHEETS['users'])
            
            if len(data) < 2:  # No data rows
                return None
                
            for row in data[1:]:  # Skip header
                if len(row) > 0 and row[0] == user_id:
                    return self._row_to_user_dict(row)
                    
            return None
            
        except Exception as e:
            print(f"Error getting user by ID: {e}")
            return None
    
    async def update_user(self, user_id: str, update_data: dict) -> Optional[dict]:
        """Update user data"""
        try:
            data = self._get_sheet_data(self.SHEETS['users'])
            
            if len(data) < 2:  # No data rows
                return None
                
            for i, row in enumerate(data[1:], 1):  # Skip header
                if len(row) > 0 and row[0] == user_id:
                    # Update the row
                    for key, value in update_data.items():
                        if key in self.USER_COLUMNS:
                            col_index = self.USER_COLUMNS.index(key)
                            if col_index < len(row):
                                row[col_index] = value
                    
                    # Update timestamp
                    row[20] = datetime.utcnow().isoformat()  # updated_at
                    
                    # Update in sheet
                    self._update_sheet_data(
                        self.SHEETS['users'],
                        f'A{i+1}:Z{i+1}',
                        [row]
                    )
                    
                    return self._row_to_user_dict(row)
                    
            return None
            
        except Exception as e:
            print(f"Error updating user: {e}")
            return None
    
    def _row_to_user_dict(self, row: List[Any]) -> dict:
        """Convert row data to user dictionary"""
        user_dict = {}
        
        for i, column in enumerate(self.USER_COLUMNS):
            if i < len(row):
                value = row[i]
                # Convert boolean strings
                if value in ['TRUE', 'FALSE']:
                    value = value == 'TRUE'
                # Convert numeric strings
                elif column in ['age', 'preferred_age_min', 'preferred_age_max', 'gems']:
                    try:
                        value = int(value)
                    except:
                        value = 0
                # Clean up gender values
                elif column == 'gender' and isinstance(value, str):
                    # Remove "Gender." prefix if it exists
                    if value.startswith('Gender.'):
                        value = value.replace('Gender.', '')
                    # Convert empty string to None for optional fields
                    if not value:
                        value = None
                # Clean up preferred_gender
                elif column == 'preferred_gender' and isinstance(value, str):
                    if not value:
                        value = None
                        
                user_dict[column] = value
            else:
                user_dict[column] = None
                
        return user_dict
    
    # Friend operations
    async def create_friend_request(self, from_user_id: str, to_user_id: str) -> dict:
        """Create a friend request"""
        try:
            friend_id = str(uuid4())
            now = datetime.utcnow().isoformat()
            
            row_data = [
                friend_id,
                from_user_id,
                to_user_id,
                'pending',  # status
                False,  # is_favorite
                False,  # is_hidden
                now,  # created_at
                now   # updated_at
            ]
            
            self._append_to_sheet(self.SHEETS['friends'], [row_data])
            
            return {
                'id': friend_id,
                'from_user_id': from_user_id,
                'to_user_id': to_user_id,
                'status': 'pending',
                'created_at': now,
                'updated_at': now
            }
            
        except Exception as e:
            print(f"Error creating friend request: {e}")
            raise
    
    async def get_friends(self, user_id: str) -> List[dict]:
        """Get user's friends"""
        try:
            data = self._get_sheet_data(self.SHEETS['friends'])
            friends = []
            
            for row in data[1:]:  # Skip header
                if len(row) > 3:
                    # Check if user is involved and status is accepted
                    if (row[1] == user_id or row[2] == user_id) and row[3] == 'accepted':
                        friend_data = self._row_to_friend_dict(row)
                        friends.append(friend_data)
                        
            return friends
            
        except Exception as e:
            print(f"Error getting friends: {e}")
            return []
    
    def _row_to_friend_dict(self, row: List[Any]) -> dict:
        """Convert row data to friend dictionary"""
        return {
            'id': row[0] if len(row) > 0 else None,
            'user_id': row[1] if len(row) > 1 else None,
            'friend_id': row[2] if len(row) > 2 else None,
            'status': row[3] if len(row) > 3 else 'pending',
            'is_favorite': row[4] == 'TRUE' if len(row) > 4 else False,
            'is_hidden': row[5] == 'TRUE' if len(row) > 5 else False,
            'created_at': row[6] if len(row) > 6 else None,
            'updated_at': row[7] if len(row) > 7 else None
        }
    
    # Message operations
    async def create_message(self, message_data: dict) -> dict:
        """Create a new message"""
        try:
            message_id = str(uuid4())
            now = datetime.utcnow().isoformat()
            
            # Get or create conversation ID
            conversation_id = await self._get_or_create_conversation(
                message_data['sender_id'],
                message_data['receiver_id']
            )
            
            row_data = [
                message_id,
                conversation_id,
                message_data['sender_id'],
                message_data['content'],
                message_data.get('message_type', 'text'),
                'sent',  # status
                now,  # created_at
                now,  # updated_at
                '',   # read_at
                ''    # deleted_at
            ]
            
            self._append_to_sheet(self.SHEETS['messages'], [row_data])
            
            return {
                'id': message_id,
                'conversation_id': conversation_id,
                'sender_id': message_data['sender_id'],
                'content': message_data['content'],
                'message_type': message_data.get('message_type', 'text'),
                'status': 'sent',
                'created_at': now
            }
            
        except Exception as e:
            print(f"Error creating message: {e}")
            raise
    
    async def _get_or_create_conversation(self, user1_id: str, user2_id: str) -> str:
        """Get or create conversation between two users"""
        # Sort user IDs to ensure consistent conversation ID
        sorted_ids = sorted([user1_id, user2_id])
        conversation_id = f"conv_{sorted_ids[0]}_{sorted_ids[1]}"
        return conversation_id
    
    # Call operations
    async def create_call_record(self, call_data: dict) -> dict:
        """Create a call record"""
        try:
            call_id = str(uuid4())
            now = datetime.utcnow().isoformat()
            
            row_data = [
                call_id,
                call_data['caller_id'],
                call_data['receiver_id'],
                call_data.get('call_type', 'video'),
                'ringing',  # status
                0,  # duration
                now,  # started_at
                '',   # connected_at
                '',   # ended_at
                now   # created_at
            ]
            
            self._append_to_sheet(self.SHEETS['calls'], [row_data])
            
            return {
                'id': call_id,
                'caller_id': call_data['caller_id'],
                'receiver_id': call_data['receiver_id'],
                'call_type': call_data.get('call_type', 'video'),
                'status': 'ringing',
                'started_at': now,
                'created_at': now
            }
            
        except Exception as e:
            print(f"Error creating call record: {e}")
            raise
    
    # Transaction operations
    async def create_transaction(self, transaction_data: dict) -> dict:
        """Create a transaction record"""
        try:
            transaction_id = str(uuid4())
            now = datetime.utcnow().isoformat()
            
            row_data = [
                transaction_id,
                transaction_data['user_id'],
                transaction_data['transaction_type'],
                transaction_data['amount'],
                transaction_data.get('item_id', ''),
                transaction_data['description'],
                now  # created_at
            ]
            
            self._append_to_sheet(self.SHEETS['transactions'], [row_data])
            
            return {
                'id': transaction_id,
                'user_id': transaction_data['user_id'],
                'transaction_type': transaction_data['transaction_type'],
                'amount': transaction_data['amount'],
                'item_id': transaction_data.get('item_id'),
                'description': transaction_data['description'],
                'created_at': now
            }
            
        except Exception as e:
            print(f"Error creating transaction: {e}")
            raise