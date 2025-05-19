"""
Friends routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models.friend import Friend, FriendRequest, FriendshipStatus, FriendOut
from app.utils.auth import get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager
from app.utils.websocket_manager import ConnectionManager
import uuid

router = APIRouter(
    prefix="/friends",
    tags=["friends"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()
redis_manager = RedisManager()
ws_manager = ConnectionManager()

@router.get("/", response_model=List[FriendOut])
async def get_friends(
    current_user: dict = Depends(get_current_user_from_token),
    status_filter: FriendshipStatus = Query(None)
) -> Any:
    """Get all friends with optional status filter."""
    # Get friendships where current user is either user_id or friend_id
    filters = {}
    if status_filter:
        filters["status"] = status_filter
    
    # Get friendships where current user is the requester
    friendships_as_user = await db.query_items(
        "friends", 
        {**filters, "user_id": current_user["user_id"]}
    )
    
    # Get friendships where current user is the requested
    friendships_as_friend = await db.query_items(
        "friends", 
        {**filters, "friend_id": current_user["user_id"]}
    )
    
    # Combine and format results
    friends_out = []
    
    for friendship in friendships_as_user:
        # Get friend details
        friend = await db.get_item("users", friendship["friend_id"])
        if friend:
            # Check online status
            is_online = await redis_manager.is_user_online(friend["user_id"])
            
            friends_out.append(FriendOut(
                friendship_id=friendship["friendship_id"],
                user_id=friend["user_id"],
                username=friend["username"],
                display_name=friend["display_name"],
                profile_photo=friend.get("profile_photo"),
                status=friendship["status"],
                is_online=is_online,
                created_at=friendship["created_at"],
                updated_at=friendship["updated_at"]
            ))
    
    for friendship in friendships_as_friend:
        # Get friend details
        friend = await db.get_item("users", friendship["user_id"])
        if friend:
            # Check online status
            is_online = await redis_manager.is_user_online(friend["user_id"])
            
            friends_out.append(FriendOut(
                friendship_id=friendship["friendship_id"],
                user_id=friend["user_id"],
                username=friend["username"],
                display_name=friend["display_name"],
                profile_photo=friend.get("profile_photo"),
                status=friendship["status"],
                is_online=is_online,
                created_at=friendship["created_at"],
                updated_at=friendship["updated_at"]
            ))
    
    return friends_out

@router.post("/request", response_model=Friend)
async def send_friend_request(
    request: FriendRequest,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Send a friend request."""
    # Check if user exists
    friend = await db.get_item("users", request.friend_id)
    if not friend:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Check if already friends or request exists
    existing_friendships = await db.query_items(
        "friends",
        {"user_id": current_user["user_id"], "friend_id": request.friend_id}
    )
    
    if not existing_friendships:
        existing_friendships = await db.query_items(
            "friends",
            {"user_id": request.friend_id, "friend_id": current_user["user_id"]}
        )
    
    if existing_friendships:
        friendship = existing_friendships[0]
        if friendship["status"] == FriendshipStatus.ACCEPTED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already friends"
            )
        elif friendship["status"] == FriendshipStatus.PENDING:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Friend request already exists"
            )
    
    # Create friend request
    friendship_id = str(uuid.uuid4())
    new_friendship = {
        "friendship_id": friendship_id,
        "user_id": current_user["user_id"],
        "friend_id": request.friend_id,
        "status": FriendshipStatus.PENDING,
        "created_at": db._get_current_time(),
        "updated_at": db._get_current_time()
    }
    
    await db.create_item("friends", new_friendship)
    
    # Send notification via WebSocket if friend is online
    if await redis_manager.is_user_online(request.friend_id):
        await ws_manager.send_notification(
            request.friend_id,
            {
                "type": "friend_request",
                "from_user": current_user["username"],
                "from_user_id": current_user["user_id"],
                "friendship_id": friendship_id
            }
        )
    
    return Friend(**new_friendship)

@router.put("/{friendship_id}/accept", response_model=Friend)
async def accept_friend_request(
    friendship_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Accept a friend request."""
    # Get friendship
    friendship = await db.get_item("friends", friendship_id)
    
    if not friendship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found"
        )
    
    # Check if current user is the recipient
    if friendship["friend_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only accept requests sent to you"
        )
    
    # Check if request is pending
    if friendship["status"] != FriendshipStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Friend request is not pending"
        )
    
    # Update friendship status
    updated_data = {
        "status": FriendshipStatus.ACCEPTED,
        "accepted_at": db._get_current_time(),
        "updated_at": db._get_current_time()
    }
    
    await db.update_item("friends", friendship_id, updated_data)
    
    # Get updated friendship
    updated_friendship = await db.get_item("friends", friendship_id)
    
    # Send notification to requester
    if await redis_manager.is_user_online(friendship["user_id"]):
        await ws_manager.send_notification(
            friendship["user_id"],
            {
                "type": "friend_request_accepted",
                "from_user": current_user["username"],
                "from_user_id": current_user["user_id"],
                "friendship_id": friendship_id
            }
        )
    
    return Friend(**updated_friendship)

@router.put("/{friendship_id}/reject", response_model=Friend)
async def reject_friend_request(
    friendship_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Reject a friend request."""
    # Get friendship
    friendship = await db.get_item("friends", friendship_id)
    
    if not friendship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friend request not found"
        )
    
    # Check if current user is the recipient
    if friendship["friend_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only reject requests sent to you"
        )
    
    # Check if request is pending
    if friendship["status"] != FriendshipStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Friend request is not pending"
        )
    
    # Update friendship status
    updated_data = {
        "status": FriendshipStatus.REJECTED,
        "rejected_at": db._get_current_time(),
        "updated_at": db._get_current_time()
    }
    
    await db.update_item("friends", friendship_id, updated_data)
    
    # Get updated friendship
    updated_friendship = await db.get_item("friends", friendship_id)
    
    # Send notification to requester
    if await redis_manager.is_user_online(friendship["user_id"]):
        await ws_manager.send_notification(
            friendship["user_id"],
            {
                "type": "friend_request_rejected",
                "from_user": current_user["username"],
                "from_user_id": current_user["user_id"],
                "friendship_id": friendship_id
            }
        )
    
    return Friend(**updated_friendship)

@router.delete("/{friendship_id}")
async def remove_friend(
    friendship_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Remove a friend or cancel a friend request."""
    # Get friendship
    friendship = await db.get_item("friends", friendship_id)
    
    if not friendship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Friendship not found"
        )
    
    # Check if current user is part of this friendship
    if friendship["user_id"] != current_user["user_id"] and friendship["friend_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not part of this friendship"
        )
    
    # Delete friendship
    await db.delete_item("friends", friendship_id)
    
    # Determine the other user
    other_user_id = friendship["friend_id"] if friendship["user_id"] == current_user["user_id"] else friendship["user_id"]
    
    # Send notification to the other user
    if await redis_manager.is_user_online(other_user_id):
        await ws_manager.send_notification(
            other_user_id,
            {
                "type": "friend_removed",
                "from_user": current_user["username"],
                "from_user_id": current_user["user_id"],
                "friendship_id": friendship_id
            }
        )
    
    return {"message": "Friend removed successfully"}

@router.get("/pending/sent", response_model=List[FriendOut])
async def get_sent_requests(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get sent friend requests."""
    # Get pending requests sent by current user
    sent_requests = await db.query_items(
        "friends",
        {"user_id": current_user["user_id"], "status": FriendshipStatus.PENDING}
    )
    
    friends_out = []
    
    for request in sent_requests:
        # Get friend details
        friend = await db.get_item("users", request["friend_id"])
        if friend:
            # Check online status
            is_online = await redis_manager.is_user_online(friend["user_id"])
            
            friends_out.append(FriendOut(
                friendship_id=request["friendship_id"],
                user_id=friend["user_id"],
                username=friend["username"],
                display_name=friend["display_name"],
                profile_photo=friend.get("profile_photo"),
                status=request["status"],
                is_online=is_online,
                created_at=request["created_at"],
                updated_at=request["updated_at"]
            ))
    
    return friends_out

@router.get("/pending/received", response_model=List[FriendOut])
async def get_received_requests(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get received friend requests."""
    # Get pending requests received by current user
    received_requests = await db.query_items(
        "friends",
        {"friend_id": current_user["user_id"], "status": FriendshipStatus.PENDING}
    )
    
    friends_out = []
    
    for request in received_requests:
        # Get friend details
        friend = await db.get_item("users", request["user_id"])
        if friend:
            # Check online status
            is_online = await redis_manager.is_user_online(friend["user_id"])
            
            friends_out.append(FriendOut(
                friendship_id=request["friendship_id"],
                user_id=friend["user_id"],
                username=friend["username"],
                display_name=friend["display_name"],
                profile_photo=friend.get("profile_photo"),
                status=request["status"],
                is_online=is_online,
                created_at=request["created_at"],
                updated_at=request["updated_at"]
            ))
    
    return friends_out