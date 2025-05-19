"""
User routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models.user import User, UserUpdate, UserFilter
from app.utils.auth import get_current_user, get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager

router = APIRouter(
    prefix="/users",
    tags=["users"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()
redis_manager = RedisManager()

@router.get("/me", response_model=User)
async def get_current_user_info(current_user: dict = Depends(get_current_user_from_token)) -> Any:
    """Get current user profile."""
    return User(**current_user)

@router.put("/me", response_model=User)
async def update_current_user(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Update current user profile."""
    # Update user in database
    update_data = user_update.dict(exclude_unset=True)
    if update_data:
        update_data["updated_at"] = db._get_current_time()
        await db.update_item("users", current_user["user_id"], update_data)
    
    # Get updated user
    updated_user = await db.get_item("users", current_user["user_id"])
    
    # Update online status in Redis if needed
    if "status" in update_data:
        if update_data["status"] == "online":
            await redis_manager.set_user_online(current_user["user_id"])
        else:
            await redis_manager.set_user_offline(current_user["user_id"])
    
    return User(**updated_user)

@router.get("/online", response_model=List[User])
async def get_online_users(
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Get list of online users."""
    # Get online user IDs from Redis
    online_user_ids = await redis_manager.get_online_users()
    
    # Filter out current user
    online_user_ids = [uid for uid in online_user_ids if uid != current_user["user_id"]]
    
    # Apply pagination
    paginated_user_ids = online_user_ids[offset:offset + limit]
    
    # Get user details from database
    users = []
    for user_id in paginated_user_ids:
        user = await db.get_item("users", user_id)
        if user:
            users.append(User(**user))
    
    return users

@router.get("/search", response_model=List[User])
async def search_users(
    current_user: dict = Depends(get_current_user_from_token),
    username: str = Query(None, min_length=1),
    display_name: str = Query(None, min_length=1),
    country: str = Query(None),
    interests: List[str] = Query(None),
    min_age: int = Query(None, ge=18),
    max_age: int = Query(None, le=100),
    gender: str = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Search users with filters."""
    # Build query filters
    filters = {}
    
    if username:
        filters["username"] = username
    if display_name:
        filters["display_name"] = display_name
    if country:
        filters["country"] = country
    if gender:
        filters["gender"] = gender
    
    # Query users
    users = await db.query_items("users", filters)
    
    # Apply additional filters
    filtered_users = []
    for user in users:
        # Skip current user
        if user["user_id"] == current_user["user_id"]:
            continue
            
        # Age filter
        if min_age and user.get("age", 0) < min_age:
            continue
        if max_age and user.get("age", 999) > max_age:
            continue
            
        # Interests filter
        if interests:
            user_interests = user.get("interests", [])
            if not any(interest in user_interests for interest in interests):
                continue
        
        filtered_users.append(User(**user))
    
    # Apply pagination
    return filtered_users[offset:offset + limit]

@router.get("/{user_id}", response_model=User)
async def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get user by ID."""
    user = await db.get_item("users", user_id)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    return User(**user)

@router.delete("/me")
async def delete_current_user(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Delete current user account."""
    # Set user offline
    await redis_manager.set_user_offline(current_user["user_id"])
    
    # Delete user from database
    await db.delete_item("users", current_user["user_id"])
    
    # Delete related data (friends, chats, etc.)
    # This should be done in a transaction in a real app
    
    # Delete friends
    friends = await db.query_items("friends", {"user_id": current_user["user_id"]})
    for friend in friends:
        await db.delete_item("friends", friend["friendship_id"])
    
    # Delete friend requests
    friends = await db.query_items("friends", {"friend_id": current_user["user_id"]})
    for friend in friends:
        await db.delete_item("friends", friend["friendship_id"])
    
    # Delete chats (simplified - in real app, handle group chats differently)
    chats = await db.query_items("chats", {"sender_id": current_user["user_id"]})
    for chat in chats:
        await db.delete_item("chats", chat["message_id"])
    
    chats = await db.query_items("chats", {"receiver_id": current_user["user_id"]})
    for chat in chats:
        await db.delete_item("chats", chat["message_id"])
    
    return {"message": "Account deleted successfully"}

@router.get("/suggestions", response_model=List[User])
async def get_user_suggestions(
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = Query(10, ge=1, le=50)
) -> Any:
    """Get user suggestions based on interests and location."""
    # Get current user's interests and location
    user_interests = current_user.get("interests", [])
    user_country = current_user.get("country", "")
    user_age = current_user.get("age", 0)
    
    # Get all users
    all_users = await db.query_items("users", {})
    
    # Score users based on common interests and location
    scored_users = []
    for user in all_users:
        # Skip current user
        if user["user_id"] == current_user["user_id"]:
            continue
            
        # Skip inactive users
        if user.get("status") != "active":
            continue
        
        score = 0
        
        # Common interests
        common_interests = set(user.get("interests", [])) & set(user_interests)
        score += len(common_interests) * 10
        
        # Same country
        if user.get("country") == user_country:
            score += 5
        
        # Similar age (within 5 years)
        age_diff = abs(user.get("age", 0) - user_age)
        if age_diff <= 5:
            score += 3
        
        # Online status
        is_online = await redis_manager.is_user_online(user["user_id"])
        if is_online:
            score += 2
        
        if score > 0:
            scored_users.append((score, user))
    
    # Sort by score and get top results
    scored_users.sort(key=lambda x: x[0], reverse=True)
    
    suggestions = []
    for score, user in scored_users[:limit]:
        suggestions.append(User(**user))
    
    return suggestions