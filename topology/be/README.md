# Topology Backend API

FastAPI backend for the Topology video chat application.

## Features

- User authentication with JWT
- Friend management
- Real-time chat with WebSocket
- Video call signaling
- Store/marketplace
- User filters
- Google Sheets as database
- Redis for caching and real-time features

## Setup

### Prerequisites

- Python 3.9+
- Redis server
- Google Cloud account with Sheets API enabled

### Installation

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up Google Sheets:
   - Create a Google Cloud project
   - Enable Google Sheets API
   - Create service account credentials
   - Download credentials JSON file
   - Share your Google Sheet with the service account email

4. Configure environment:
```bash
cp .env.example .env
# Edit .env file with your configurations
```

5. Run the application:
```bash
uvicorn main:app --reload
```

The API will be available at http://localhost:8000

## API Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Environment Variables

- `GOOGLE_SHEETS_SPREADSHEET_ID`: Your Google Sheets ID
- `GOOGLE_SHEETS_CREDENTIALS_PATH`: Path to Google credentials JSON
- `REDIS_HOST`: Redis server host (default: localhost)
- `REDIS_PORT`: Redis server port (default: 6379)
- `SECRET_KEY`: JWT secret key for authentication

## WebSocket Connection

Connect to WebSocket at: `ws://localhost:8000/ws?token={access_token}`

### Message Types

- `ping`: Keep-alive message
- `typing`: Typing indicator
- `message`: Chat message
- `call_signal`: WebRTC signaling
- `ice_candidate`: WebRTC ICE candidate
- `presence_query`: Query user online status
- `location_update`: Update user location

## Database Schema (Google Sheets)

### Users Sheet
- user_id (string)
- email (string)
- username (string)
- display_name (string)
- password_hash (string)
- age (number)
- gender (string)
- country (string)
- status (string)
- account_type (string)
- created_at (datetime)
- updated_at (datetime)

### Friends Sheet
- friendship_id (string)
- user_id (string)
- friend_id (string)
- status (string)
- created_at (datetime)
- updated_at (datetime)

### Chats Sheet
- message_id (string)
- sender_id (string)
- receiver_id (string)
- content (string)
- is_read (boolean)
- created_at (datetime)

### Video Calls Sheet
- call_id (string)
- caller_id (string)
- receiver_id (string)
- status (string)
- started_at (datetime)
- ended_at (datetime)
- duration (number)

### Store Items Sheet
- item_id (string)
- name (string)
- description (string)
- price (number)
- category (string)
- stock (number)
- is_active (boolean)
- created_at (datetime)

### Purchases Sheet
- purchase_id (string)
- user_id (string)
- item_id (string)
- quantity (number)
- total_price (number)
- status (string)
- created_at (datetime)

### Filters Sheet
- filter_id (string)
- user_id (string)
- name (string)
- age_range (object)
- genders (array)
- countries (array)
- interests (array)
- only_online (boolean)
- is_active (boolean)
- created_at (datetime)

## Testing

Run tests:
```bash
pytest
```

## Deployment

1. Set production environment variables
2. Update CORS settings for production domains
3. Use production Redis instance
4. Deploy with your preferred method (Docker, Kubernetes, etc.)

## License

MIT