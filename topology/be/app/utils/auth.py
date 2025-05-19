"""
Authentication utilities
"""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import os
import bcrypt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

# JWT settings
SECRET_KEY = os.environ.get("SECRET_KEY", "your-secret-key-here")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password using bcrypt directly"""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password: str) -> str:
    """Hash password using bcrypt directly"""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

# Unified token creation functions
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create access token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_refresh_token(data: dict):
    """Create refresh token"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Get current user from token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print(f"Access token payload: {payload}")
        
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        # Handle case where sub might be nested
        if isinstance(user_id, dict) and "sub" in user_id:
            user_id = user_id["sub"]
            print(f"Extracted nested user_id: {user_id}")
        
        if user_id is None or token_type != "access":
            print(f"Invalid access token: user_id={user_id}, token_type={token_type}")
            raise credentials_exception
            
    except JWTError:
        raise credentials_exception
    
    # Get user from database
    from app.utils.google_sheets import GoogleSheetsManager
    db = GoogleSheetsManager.get_instance()
    user = await db.get_user_by_id(user_id)
    
    if user is None:
        raise credentials_exception
        
    return user

async def get_current_active_user(current_user: dict = Depends(get_current_user)):
    """Get current active user"""
    if not current_user.get("is_active"):
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

def verify_refresh_token(token: str) -> Optional[str]:
    """Verify refresh token and return user_id"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print(f"Refresh token payload: {payload}")
        
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        # Handle case where sub might be nested
        if isinstance(user_id, dict) and "sub" in user_id:
            user_id = user_id["sub"]
            print(f"Extracted nested user_id: {user_id}")
        
        if user_id is None or token_type != "refresh":
            print(f"Invalid token: user_id={user_id}, token_type={token_type}")
            return None
            
        return user_id
        
    except JWTError as e:
        print(f"JWT decode error: {e}")
        return None

def create_password_reset_token(email: str) -> str:
    """Create password reset token"""
    data = {"sub": email, "type": "reset"}
    expire = datetime.utcnow() + timedelta(hours=1)
    
    data.update({"exp": expire})
    token = jwt.encode(data, SECRET_KEY, algorithm=ALGORITHM)
    return token

def verify_password_reset_token(token: str) -> Optional[str]:
    """Verify password reset token and return email"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        if email is None or token_type != "reset":
            return None
            
        return email
        
    except JWTError:
        return None

async def verify_websocket_token(token: str) -> Optional[str]:
    """Verify WebSocket connection token and return user_id"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        # Handle case where sub might be nested
        if isinstance(user_id, dict) and "sub" in user_id:
            user_id = user_id["sub"]
        
        if user_id is None or token_type != "access":
            return None
            
        # Verify user exists and is active
        from app.utils.google_sheets import GoogleSheetsManager
        db = GoogleSheetsManager.get_instance()
        user = await db.get_item("users", user_id)
        
        if not user or user.get("status") == "banned":
            return None
            
        return user_id
        
    except JWTError:
        return None

async def get_current_user_from_token(token: str = Depends(oauth2_scheme)):
    """Get current user from token with detailed user info"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")
        
        # Handle case where sub might be nested
        if isinstance(user_id, dict) and "sub" in user_id:
            user_id = user_id["sub"]
        
        if user_id is None or token_type != "access":
            raise credentials_exception
            
    except JWTError:
        raise credentials_exception
    
    # Get user from database
    from app.utils.google_sheets import GoogleSheetsManager
    db = GoogleSheetsManager.get_instance()
    user = await db.get_item("users", user_id)
    
    if user is None:
        raise credentials_exception
        
    return user

# Removed duplicate function definitions

def decode_access_token(token: str) -> dict:
    """Decode access token and return payload"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )