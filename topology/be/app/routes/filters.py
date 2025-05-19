"""
Filter routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status
from models.filter import Filter, FilterCreate, FilterUpdate
from app.utils.auth import get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
import uuid

router = APIRouter(
    prefix="/filters",
    tags=["filters"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()

@router.get("/", response_model=List[Filter])
async def get_user_filters(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get all filters for current user."""
    filters = await db.query_items("filters", {"user_id": current_user["user_id"]})
    return [Filter(**filter_data) for filter_data in filters]

@router.post("/", response_model=Filter)
async def create_filter(
    filter_data: FilterCreate,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Create a new filter."""
    # Check if user already has a filter with the same name
    existing_filters = await db.query_items(
        "filters",
        {"user_id": current_user["user_id"], "name": filter_data.name}
    )
    
    if existing_filters:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Filter with this name already exists"
        )
    
    # Check maximum filters limit (e.g., 10 per user)
    user_filters = await db.query_items("filters", {"user_id": current_user["user_id"]})
    if len(user_filters) >= 10:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum number of filters (10) reached"
        )
    
    # Create new filter
    filter_id = str(uuid.uuid4())
    new_filter = {
        "filter_id": filter_id,
        "user_id": current_user["user_id"],
        "name": filter_data.name,
        "age_range": filter_data.age_range.dict() if filter_data.age_range else None,
        "genders": filter_data.genders,
        "countries": filter_data.countries,
        "interests": filter_data.interests,
        "languages": filter_data.languages,
        "only_online": filter_data.only_online,
        "only_verified": filter_data.only_verified,
        "is_active": True,
        "created_at": db._get_current_time(),
        "updated_at": db._get_current_time()
    }
    
    await db.create_item("filters", new_filter)
    
    return Filter(**new_filter)

@router.get("/{filter_id}", response_model=Filter)
async def get_filter(
    filter_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get a specific filter."""
    filter_data = await db.get_item("filters", filter_id)
    
    if not filter_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Filter not found"
        )
    
    # Check if filter belongs to current user
    if filter_data["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only access your own filters"
        )
    
    return Filter(**filter_data)

@router.put("/{filter_id}", response_model=Filter)
async def update_filter(
    filter_id: str,
    filter_update: FilterUpdate,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Update a filter."""
    # Get existing filter
    filter_data = await db.get_item("filters", filter_id)
    
    if not filter_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Filter not found"
        )
    
    # Check if filter belongs to current user
    if filter_data["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only update your own filters"
        )
    
    # Check if name is being changed and if it conflicts
    if filter_update.name and filter_update.name != filter_data["name"]:
        existing_filters = await db.query_items(
            "filters",
            {"user_id": current_user["user_id"], "name": filter_update.name}
        )
        
        if existing_filters:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Filter with this name already exists"
            )
    
    # Update filter
    update_data = filter_update.dict(exclude_unset=True)
    if "age_range" in update_data and update_data["age_range"]:
        update_data["age_range"] = update_data["age_range"].dict()
    
    update_data["updated_at"] = db._get_current_time()
    
    await db.update_item("filters", filter_id, update_data)
    
    # Get updated filter
    updated_filter = await db.get_item("filters", filter_id)
    
    return Filter(**updated_filter)

@router.delete("/{filter_id}")
async def delete_filter(
    filter_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Delete a filter."""
    # Get filter
    filter_data = await db.get_item("filters", filter_id)
    
    if not filter_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Filter not found"
        )
    
    # Check if filter belongs to current user
    if filter_data["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own filters"
        )
    
    # Delete filter
    await db.delete_item("filters", filter_id)
    
    return {"message": "Filter deleted successfully"}

@router.post("/{filter_id}/apply", response_model=List[dict])
async def apply_filter(
    filter_id: str,
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = 20
) -> Any:
    """Apply a filter to get matching users."""
    # Get filter
    filter_data = await db.get_item("filters", filter_id)
    
    if not filter_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Filter not found"
        )
    
    # Check if filter belongs to current user
    if filter_data["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only apply your own filters"
        )
    
    # Get all users
    all_users = await db.query_items("users", {"status": "active"})
    
    # Apply filters
    matching_users = []
    
    for user in all_users:
        # Skip current user
        if user["user_id"] == current_user["user_id"]:
            continue
        
        # Age filter
        if filter_data.get("age_range"):
            age_range = filter_data["age_range"]
            user_age = user.get("age", 0)
            
            if age_range.get("min") and user_age < age_range["min"]:
                continue
            if age_range.get("max") and user_age > age_range["max"]:
                continue
        
        # Gender filter
        if filter_data.get("genders"):
            if user.get("gender") not in filter_data["genders"]:
                continue
        
        # Country filter
        if filter_data.get("countries"):
            if user.get("country") not in filter_data["countries"]:
                continue
        
        # Interests filter
        if filter_data.get("interests"):
            user_interests = set(user.get("interests", []))
            filter_interests = set(filter_data["interests"])
            
            if not user_interests.intersection(filter_interests):
                continue
        
        # Languages filter
        if filter_data.get("languages"):
            user_languages = set(user.get("languages", []))
            filter_languages = set(filter_data["languages"])
            
            if not user_languages.intersection(filter_languages):
                continue
        
        # Online status filter
        if filter_data.get("only_online"):
            # Check with Redis
            from app.utils.redis_manager import RedisManager
            redis_manager = RedisManager()
            
            if not await redis_manager.is_user_online(user["user_id"]):
                continue
        
        # Verified status filter
        if filter_data.get("only_verified"):
            if not user.get("is_verified", False):
                continue
        
        # User matches all filters
        matching_users.append({
            "user_id": user["user_id"],
            "username": user["username"],
            "display_name": user["display_name"],
            "age": user.get("age"),
            "gender": user.get("gender"),
            "country": user.get("country"),
            "interests": user.get("interests", []),
            "profile_photo": user.get("profile_photo"),
            "is_online": await redis_manager.is_user_online(user["user_id"]) if 'redis_manager' in locals() else False
        })
    
    # Apply limit
    return matching_users[:limit]

@router.get("/active", response_model=Filter)
async def get_active_filter(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get the currently active filter."""
    filters = await db.query_items(
        "filters",
        {"user_id": current_user["user_id"], "is_active": True}
    )
    
    if not filters:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active filter found"
        )
    
    # Return the first active filter (there should only be one)
    return Filter(**filters[0])

@router.put("/{filter_id}/activate", response_model=Filter)
async def activate_filter(
    filter_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Activate a filter (deactivates all others)."""
    # Get filter
    filter_data = await db.get_item("filters", filter_id)
    
    if not filter_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Filter not found"
        )
    
    # Check if filter belongs to current user
    if filter_data["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only activate your own filters"
        )
    
    # Deactivate all user's filters
    user_filters = await db.query_items("filters", {"user_id": current_user["user_id"]})
    
    for f in user_filters:
        if f["filter_id"] != filter_id:
            await db.update_item(
                "filters",
                f["filter_id"],
                {"is_active": False, "updated_at": db._get_current_time()}
            )
    
    # Activate the selected filter
    await db.update_item(
        "filters",
        filter_id,
        {"is_active": True, "updated_at": db._get_current_time()}
    )
    
    # Get updated filter
    updated_filter = await db.get_item("filters", filter_id)
    
    return Filter(**updated_filter)