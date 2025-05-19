"""
User data models
"""
from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List
from datetime import datetime
from enum import Enum

class Gender(str, Enum):
    male = "male"
    female = "female"
    other = "other"
    prefer_not_to_say = "prefer_not_to_say"

class UserStatus(str, Enum):
    online = "online"
    offline = "offline"
    busy = "busy"
    away = "away"

class UserRole(str, Enum):
    user = "user"
    premium = "premium"
    admin = "admin"

class UserBase(BaseModel):
    email: EmailStr
    username: str = Field(..., min_length=3, max_length=50)
    display_name: str = Field(..., min_length=1, max_length=100)
    age: int = Field(..., ge=18, le=100)
    gender: Gender
    country: str
    bio: Optional[str] = Field(None, max_length=500)
    profile_image_url: Optional[str] = None
    preferred_gender: Optional[Gender] = None
    preferred_age_min: int = Field(default=18, ge=18, le=100)
    preferred_age_max: int = Field(default=100, ge=18, le=100)
    is_profile_public: bool = True
    allow_random_calls: bool = True

class UserCreate(UserBase):
    password: str = Field(..., min_length=8)

class UserUpdate(BaseModel):
    display_name: Optional[str] = None
    bio: Optional[str] = None
    profile_image_url: Optional[str] = None
    preferred_gender: Optional[Gender] = None
    preferred_age_min: Optional[int] = None
    preferred_age_max: Optional[int] = None
    is_profile_public: Optional[bool] = None
    allow_random_calls: Optional[bool] = None

class UserInDB(UserBase):
    id: str
    hashed_password: str
    role: UserRole = UserRole.user
    gems: int = 0
    status: UserStatus = UserStatus.offline
    last_seen: datetime
    created_at: datetime
    updated_at: datetime
    is_active: bool = True
    is_verified: bool = False
    
class User(UserBase):
    id: str
    display_name: str
    role: Optional[UserRole] = UserRole.user
    gems: Optional[int] = 0
    status: Optional[UserStatus] = UserStatus.offline
    last_seen: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    is_active: Optional[bool] = True
    is_verified: Optional[bool] = False
    interests: Optional[List[str]] = []
    photos: Optional[List[str]] = []
    location: Optional[dict] = None
    account_type: Optional[str] = "standard"

class UserResponse(BaseModel):
    user: User
    message: str = "Success"

class UserListResponse(BaseModel):
    users: List[User]
    total: int
    page: int
    page_size: int

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    user: User
    
class PasswordResetRequest(BaseModel):
    email: EmailStr
    
class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str = Field(..., min_length=8)

class UserFilter(BaseModel):
    age_min: Optional[int] = Field(None, ge=18)
    age_max: Optional[int] = Field(None, le=100)
    gender: Optional[Gender] = None
    country: Optional[str] = None
    status: Optional[UserStatus] = None
    search: Optional[str] = None