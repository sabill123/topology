"""
Authentication routes
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from models.user import UserCreate, User, TokenResponse, LoginRequest, PasswordResetRequest, PasswordResetConfirm, Gender
from app.utils.auth import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    verify_refresh_token,
    create_password_reset_token,
    verify_password_reset_token,
    get_current_user
)
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager
import os

router = APIRouter()

@router.post("/register", response_model=TokenResponse)
async def register(user_data: UserCreate):
    """Register new user"""
    db = GoogleSheetsManager.get_instance()
    
    # Debug print received data
    print(f"Received user_data: {user_data.dict()}")
    
    # Check if user already exists
    existing_user = await db.get_user_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create user
    user_dict = user_data.dict()
    print(f"user_dict before password: {user_dict}")
    
    try:
        password = user_dict.pop("password")
        print(f"Password extracted: {password[:3]}...")  # Print first 3 chars for debug
        
        hashed_pw = get_password_hash(password)
        print(f"Password hashed successfully")
        
        user_dict["hashed_password"] = hashed_pw
    except KeyError as e:
        print(f"KeyError: {e}")
        print(f"Available keys: {user_dict.keys()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating user: missing password field"
        )
    except Exception as e:
        print(f"Error hashing password: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating user: {str(e)}"
        )
    
    try:
        print(f"user_dict before creating user: {user_dict.keys()}")
        created_user = await db.create_user(user_dict)
        print(f"User created successfully: {created_user.get('id')}")
    except Exception as e:
        print(f"Exception in create_user: {type(e).__name__}: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error creating user: {str(e)}"
        )
    
    # Create tokens
    access_token = create_access_token({"sub": created_user["id"]})
    refresh_token = create_refresh_token({"sub": created_user["id"]})
    
    # Debug: Check token payload
    print(f"Creating tokens for new user_id: {created_user['id']}")
    print(f"Token payload: {{'sub': {created_user['id']}}}")
    
    # Set user online
    redis = RedisManager.get_instance()
    await redis.set_user_online(created_user["id"])
    
    # Remove sensitive data
    created_user.pop('hashed_password', None)
    
    # Clean up gender value if needed
    gender_value = created_user.get('gender')
    if isinstance(gender_value, str) and gender_value.startswith('Gender.'):
        created_user['gender'] = gender_value.replace('Gender.', '')
    elif hasattr(gender_value, 'value'):
        created_user['gender'] = gender_value.value
    
    # Convert preferred_gender if present and is enum
    if created_user.get('preferred_gender') and hasattr(created_user.get('preferred_gender'), 'value'):
        created_user['preferred_gender'] = created_user['preferred_gender'].value
    
    # Convert status and role to proper enum values if they are strings
    if isinstance(created_user.get('status'), str):
        from models.user import UserStatus
        created_user['status'] = UserStatus(created_user['status'])
    
    if isinstance(created_user.get('role'), str):
        from models.user import UserRole
        created_user['role'] = UserRole(created_user['role'])
    
    # Parse datetime fields if they are strings
    from datetime import datetime
    for date_field in ['last_seen', 'created_at', 'updated_at']:
        if date_field in created_user and isinstance(created_user[date_field], str):
            try:
                # Try to parse ISO format
                created_user[date_field] = datetime.fromisoformat(created_user[date_field].replace('Z', '+00:00'))
            except:
                try:
                    # Try to parse with microseconds
                    created_user[date_field] = datetime.strptime(created_user[date_field], "%Y-%m-%dT%H:%M:%S.%f")
                except:
                    # Set to None if parsing fails
                    created_user[date_field] = None
    
    print(f"Created user data before User model: {created_user}")
    
    user_response = User(**created_user)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user_response
    )

@router.post("/login", response_model=TokenResponse)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Login user"""
    db = GoogleSheetsManager.get_instance()
    
    # Get user by email
    user = await db.get_user_by_email(form_data.username)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Verify password
    if not verify_password(form_data.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if user is active
    if not user.get("is_active", True):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )
    
    # Create tokens - pass the user ID directly as string
    access_token = create_access_token({"sub": user["id"]})
    refresh_token = create_refresh_token({"sub": user["id"]})
    
    # Debug: Check token payload
    print(f"Creating tokens for user_id: {user['id']}")
    print(f"Token payload: {{'sub': {user['id']}}}")
    
    # Update last seen and set user online
    redis = RedisManager.get_instance()
    await redis.set_user_online(user["id"])
    await db.update_user(user["id"], {"status": "online"})
    
    # Remove sensitive data
    user.pop('hashed_password', None)
    
    # Convert Gender enum to string if needed
    if hasattr(user.get('gender'), 'value'):
        user['gender'] = user['gender'].value
    
    # Convert preferred_gender if present
    if user.get('preferred_gender') and hasattr(user.get('preferred_gender'), 'value'):
        user['preferred_gender'] = user['preferred_gender'].value
    
    # Convert status and role to proper enum values if they are strings
    if isinstance(user.get('status'), str):
        from models.user import UserStatus
        user['status'] = UserStatus(user['status'])
    
    if isinstance(user.get('role'), str):
        from models.user import UserRole
        user['role'] = UserRole(user['role'])
    
    # Parse datetime fields if they are strings
    from datetime import datetime
    for date_field in ['last_seen', 'created_at', 'updated_at']:
        if date_field in user and isinstance(user[date_field], str):
            try:
                # Try to parse ISO format
                user[date_field] = datetime.fromisoformat(user[date_field].replace('Z', '+00:00'))
            except:
                try:
                    # Try to parse with microseconds
                    user[date_field] = datetime.strptime(user[date_field], "%Y-%m-%dT%H:%M:%S.%f")
                except:
                    # Set to None if parsing fails
                    user[date_field] = None
    
    user_response = User(**user)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user_response
    )

@router.get("/me", response_model=User)
async def get_me(current_user: dict = Depends(get_current_user)):
    """Get current user info"""
    # Remove sensitive data
    current_user.pop('hashed_password', None)
    
    # Convert Gender enum to string if needed
    if hasattr(current_user.get('gender'), 'value'):
        current_user['gender'] = current_user['gender'].value
    
    return User(**current_user)

@router.post("/logout")
async def logout(current_user: dict = Depends(get_current_user)):
    """Logout user"""
    db = GoogleSheetsManager.get_instance()
    redis = RedisManager.get_instance()
    
    # Set user offline
    await redis.set_user_offline(current_user["id"])
    await db.update_user(current_user["id"], {"status": "offline"})
    
    return {"message": "Logged out successfully"}

@router.post("/refresh", response_model=TokenResponse)
async def refresh_token(body: dict):
    """Refresh access token"""
    # Get refresh token from body
    refresh_token = body.get("refresh_token")
    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="refresh_token is required"
        )
    
    # Verify refresh token
    user_id = verify_refresh_token(refresh_token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    
    # Get user
    db = GoogleSheetsManager.get_instance()
    user = await db.get_user_by_id(user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Create new access token
    access_token = create_access_token({"sub": user["id"]})
    
    # Remove sensitive data
    user.pop('hashed_password', None)
    
    # Convert Gender enum to string if needed
    if hasattr(user.get('gender'), 'value'):
        user['gender'] = user['gender'].value
        
    user_response = User(**user)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=user_response
    )

@router.post("/forgot-password")
async def forgot_password(request: PasswordResetRequest):
    """Request password reset"""
    db = GoogleSheetsManager.get_instance()
    
    # Check if user exists
    user = await db.get_user_by_email(request.email)
    if not user:
        # Don't reveal if user exists or not
        return {"message": "If the email exists, a reset link has been sent"}
    
    # Create reset token
    reset_token = create_password_reset_token(request.email)
    
    # In a real app, send email here
    # For now, just return the token (remove in production)
    if os.environ.get("DEBUG"):
        return {
            "message": "Reset link sent",
            "debug_token": reset_token
        }
    
    return {"message": "If the email exists, a reset link has been sent"}

@router.post("/reset-password")
async def reset_password(request: PasswordResetConfirm):
    """Reset password with token"""
    # Verify reset token
    email = verify_password_reset_token(request.token)
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token"
        )
    
    # Get user
    db = GoogleSheetsManager.get_instance()
    user = await db.get_user_by_email(email)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Update password
    hashed_password = get_password_hash(request.new_password)
    await db.update_user(user["id"], {"hashed_password": hashed_password})
    
    return {"message": "Password reset successfully"}