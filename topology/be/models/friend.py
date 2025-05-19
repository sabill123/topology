"""
Friend and relationship models
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class FriendshipStatus(str, Enum):
    pending = "pending"
    accepted = "accepted"
    blocked = "blocked"
    hidden = "hidden"

class FriendRequest(BaseModel):
    target_user_id: str

class FriendRequestResponse(BaseModel):
    id: str
    from_user_id: str
    to_user_id: str
    status: FriendshipStatus
    created_at: datetime
    updated_at: datetime

class Friend(BaseModel):
    id: str
    user_id: str
    friend_id: str
    status: FriendshipStatus
    is_favorite: bool = False
    is_hidden: bool = False
    created_at: datetime
    updated_at: datetime

class FriendWithProfile(BaseModel):
    friend: Friend
    profile: "User"  # Forward reference to avoid circular import

class FriendListResponse(BaseModel):
    friends: List[FriendWithProfile]
    total: int
    page: int
    page_size: int

class FriendActionRequest(BaseModel):
    friend_id: str
    action: str  # "favorite", "unfavorite", "hide", "unhide", "block", "unblock"

class FriendOut(BaseModel):
    """Friend output model with user profile"""
    friendship_id: str
    friend_id: str
    friend_info: Optional[dict] = None
    status: FriendshipStatus
    is_favorite: bool = False
    is_hidden: bool = False
    created_at: datetime
    updated_at: Optional[datetime] = None
    
from models.user import User
FriendWithProfile.model_rebuild()