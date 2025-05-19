# Topology Backend Quick Start Guide

## 1. Prerequisites

- Python 3.9+
- Redis server
- Google Cloud account (for Sheets API)

## 2. Setup Steps

### Step 1: Create Virtual Environment

```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Step 2: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 3: Configure Environment

The `.env` file has been created with your Google Sheets configuration:
- Spreadsheet ID: `1wCMvtnEqtsJdNFIgkQMNkQCGT_eiAgRDcknprwPCzhI`
- Credentials Path: `/Users/jaeseokhan/Desktop/topology/topology/topology/molten-nirvana-452907-m0-9a5104d0a9a2.json`

### Step 4: Set up Google Sheets

Run the setup script to create sheets and add headers:

```bash
python setup_sheets.py
```

**Important**: After running the setup script, you need to share your Google Sheet with the service account email found in your credentials JSON file.

### Step 5: Start Redis

If Redis is not running, start it:

```bash
# On macOS with Homebrew
brew services start redis

# Or run directly
redis-server
```

### Step 6: Run the Application

Use the start script:

```bash
./start.sh
```

Or run directly:

```bash
uvicorn main:app --reload
```

## 3. Access the API

- API Base URL: http://localhost:8000
- API Documentation: http://localhost:8000/docs
- Alternative Docs: http://localhost:8000/redoc

## 4. Test the API

### Create a Test User

```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "username": "testuser",
    "password": "password123",
    "display_name": "Test User",
    "age": 25,
    "gender": "male",
    "country": "USA"
  }'
```

### Login

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=test@example.com&password=password123"
```

## 5. Common Issues

### Google Sheets Access

If you get permission errors:
1. Check that the service account email has access to your Google Sheet
2. Make sure the Sheet ID is correct
3. Verify the credentials file path is correct

### Redis Connection

If Redis connection fails:
1. Check Redis is running: `redis-cli ping`
2. Verify Redis host/port in `.env`
3. Check Redis password if set

### Import Errors

If you get import errors:
1. Make sure virtual environment is activated
2. Run `pip install -r requirements.txt` again
3. Check Python version (should be 3.9+)

## 6. Development Tips

- Use `--reload` flag with uvicorn for hot reloading
- Check logs in the terminal for debugging
- Use the interactive API docs at `/docs` for testing
- Monitor Redis with `redis-cli monitor`

## 7. Next Steps

1. Set up iOS app to connect to this backend
2. Configure WebSocket connections for real-time features
3. Test video calling with WebRTC signaling
4. Add more test data to Google Sheets

## Support

For issues or questions:
1. Check the README.md file
2. Review API documentation at `/docs`
3. Check logs for error messages
4. Verify all credentials and configurations