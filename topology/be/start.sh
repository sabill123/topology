#!/bin/bash

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Install or update dependencies
pip install -r requirements.txt

# Run setup script if sheets need to be initialized
python setup_sheets.py

# Start the application
uvicorn main:app --reload --host 0.0.0.0 --port 8000