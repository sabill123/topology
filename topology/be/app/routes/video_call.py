"""
Video call routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models.video_call import VideoCall, VideoCallCreate, VideoCallUpdate, CallStatus
from app.utils.auth import get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager
from app.utils.websocket_manager import ConnectionManager
import uuid
import datetime

router = APIRouter(
    prefix="/video-calls",
    tags=["video-calls"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()
redis_manager = RedisManager()
ws_manager = ConnectionManager()

@router.get("/", response_model=List[VideoCall])
async def get_call_history(
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Get video call history."""
    # Get calls where user is either caller or receiver
    calls_as_caller = await db.query_items(
        "video_calls",
        {"caller_id": current_user["user_id"]}
    )
    
    calls_as_receiver = await db.query_items(
        "video_calls",
        {"receiver_id": current_user["user_id"]}
    )
    
    # Combine and sort by created_at (most recent first)
    all_calls = calls_as_caller + calls_as_receiver
    all_calls.sort(key=lambda x: x["created_at"], reverse=True)
    
    # Apply pagination
    paginated_calls = all_calls[offset:offset + limit]
    
    # Format and return
    return [VideoCall(**call) for call in paginated_calls]

@router.post("/", response_model=VideoCall)
async def initiate_call(
    call_data: VideoCallCreate,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Initiate a video call."""
    # Check if receiver exists
    receiver = await db.get_item("users", call_data.receiver_id)
    if not receiver:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receiver not found"
        )
    
    # Check if receiver is online
    if not await redis_manager.is_user_online(call_data.receiver_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User is not online"
        )
    
    # Check if there's an active call with this user
    active_calls = await db.query_items(
        "video_calls",
        {
            "status": CallStatus.ACTIVE,
            "$or": [
                {
                    "caller_id": current_user["user_id"],
                    "receiver_id": call_data.receiver_id
                },
                {
                    "caller_id": call_data.receiver_id,
                    "receiver_id": current_user["user_id"]
                }
            ]
        }
    )
    
    if active_calls:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="There's already an active call with this user"
        )
    
    # Create new call
    call_id = str(uuid.uuid4())
    new_call = {
        "call_id": call_id,
        "caller_id": current_user["user_id"],
        "receiver_id": call_data.receiver_id,
        "status": CallStatus.RINGING,
        "started_at": None,
        "ended_at": None,
        "duration": 0,
        "call_type": call_data.call_type,
        "created_at": db._get_current_time()
    }
    
    await db.create_item("video_calls", new_call)
    
    # Send notification to receiver via WebSocket
    await ws_manager.send_notification(
        call_data.receiver_id,
        {
            "type": "incoming_call",
            "call_id": call_id,
            "caller": {
                "user_id": current_user["user_id"],
                "username": current_user["username"],
                "display_name": current_user["display_name"],
                "profile_photo": current_user.get("profile_photo")
            },
            "call_type": call_data.call_type
        }
    )
    
    return VideoCall(**new_call)

@router.put("/{call_id}/accept", response_model=VideoCall)
async def accept_call(
    call_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Accept an incoming call."""
    # Get call
    call = await db.get_item("video_calls", call_id)
    
    if not call:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Call not found"
        )
    
    # Check if current user is the receiver
    if call["receiver_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only accept calls made to you"
        )
    
    # Check if call is ringing
    if call["status"] != CallStatus.RINGING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Call is not in ringing state"
        )
    
    # Update call status
    current_time = db._get_current_time()
    updated_data = {
        "status": CallStatus.ACTIVE,
        "started_at": current_time,
        "updated_at": current_time
    }
    
    await db.update_item("video_calls", call_id, updated_data)
    
    # Get updated call
    updated_call = await db.get_item("video_calls", call_id)
    
    # Notify caller that call was accepted
    await ws_manager.send_notification(
        call["caller_id"],
        {
            "type": "call_accepted",
            "call_id": call_id,
            "receiver_id": current_user["user_id"]
        }
    )
    
    # Store active call in Redis for quick access
    await redis_manager.set(
        f"active_call:{current_user['user_id']}",
        call_id,
        expire=3600  # 1 hour
    )
    await redis_manager.set(
        f"active_call:{call['caller_id']}",
        call_id,
        expire=3600
    )
    
    return VideoCall(**updated_call)

@router.put("/{call_id}/reject", response_model=VideoCall)
async def reject_call(
    call_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Reject an incoming call."""
    # Get call
    call = await db.get_item("video_calls", call_id)
    
    if not call:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Call not found"
        )
    
    # Check if current user is the receiver
    if call["receiver_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only reject calls made to you"
        )
    
    # Check if call is ringing
    if call["status"] != CallStatus.RINGING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Call is not in ringing state"
        )
    
    # Update call status
    current_time = db._get_current_time()
    updated_data = {
        "status": CallStatus.REJECTED,
        "ended_at": current_time,
        "updated_at": current_time
    }
    
    await db.update_item("video_calls", call_id, updated_data)
    
    # Get updated call
    updated_call = await db.get_item("video_calls", call_id)
    
    # Notify caller that call was rejected
    await ws_manager.send_notification(
        call["caller_id"],
        {
            "type": "call_rejected",
            "call_id": call_id,
            "receiver_id": current_user["user_id"]
        }
    )
    
    return VideoCall(**updated_call)

@router.put("/{call_id}/end", response_model=VideoCall)
async def end_call(
    call_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """End an active call."""
    # Get call
    call = await db.get_item("video_calls", call_id)
    
    if not call:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Call not found"
        )
    
    # Check if current user is part of the call
    if call["caller_id"] != current_user["user_id"] and call["receiver_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not part of this call"
        )
    
    # Check if call is active or ringing
    if call["status"] not in [CallStatus.ACTIVE, CallStatus.RINGING]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Call is not active or ringing"
        )
    
    # Update call status
    current_time = db._get_current_time()
    ended_at = current_time
    
    # Calculate duration if call was active
    duration = 0
    if call["status"] == CallStatus.ACTIVE and call["started_at"]:
        started = datetime.fromisoformat(call["started_at"].replace('Z', '+00:00'))
        ended = datetime.fromisoformat(ended_at.replace('Z', '+00:00'))
        duration = int((ended - started).total_seconds())
    
    updated_data = {
        "status": CallStatus.ENDED,
        "ended_at": ended_at,
        "duration": duration,
        "updated_at": current_time
    }
    
    await db.update_item("video_calls", call_id, updated_data)
    
    # Get updated call
    updated_call = await db.get_item("video_calls", call_id)
    
    # Remove active call from Redis
    await redis_manager.delete(f"active_call:{call['caller_id']}")
    await redis_manager.delete(f"active_call:{call['receiver_id']}")
    
    # Notify the other user that call ended
    other_user_id = call["receiver_id"] if call["caller_id"] == current_user["user_id"] else call["caller_id"]
    await ws_manager.send_notification(
        other_user_id,
        {
            "type": "call_ended",
            "call_id": call_id,
            "ended_by": current_user["user_id"],
            "duration": duration
        }
    )
    
    return VideoCall(**updated_call)

@router.get("/active", response_model=VideoCall)
async def get_active_call(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get current active call."""
    # Check Redis for active call
    active_call_id = await redis_manager.get(f"active_call:{current_user['user_id']}")
    
    if not active_call_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active call"
        )
    
    # Get call details
    call = await db.get_item("video_calls", active_call_id)
    
    if not call or call["status"] != CallStatus.ACTIVE:
        # Clean up Redis if call is not active
        await redis_manager.delete(f"active_call:{current_user['user_id']}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active call"
        )
    
    return VideoCall(**call)

@router.get("/stats")
async def get_call_stats(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get video call statistics."""
    # Get all calls for user
    calls_as_caller = await db.query_items(
        "video_calls",
        {"caller_id": current_user["user_id"]}
    )
    
    calls_as_receiver = await db.query_items(
        "video_calls",
        {"receiver_id": current_user["user_id"]}
    )
    
    all_calls = calls_as_caller + calls_as_receiver
    
    # Calculate statistics
    total_calls = len(all_calls)
    total_duration = sum(call.get("duration", 0) for call in all_calls)
    
    # Count by status
    status_counts = {}
    for status in CallStatus:
        status_counts[status.value] = len([c for c in all_calls if c["status"] == status.value])
    
    # Average call duration (only for ended calls)
    ended_calls = [c for c in all_calls if c["status"] == CallStatus.ENDED and c.get("duration", 0) > 0]
    avg_duration = sum(c["duration"] for c in ended_calls) / len(ended_calls) if ended_calls else 0
    
    return {
        "total_calls": total_calls,
        "total_duration": total_duration,
        "average_duration": avg_duration,
        "calls_made": len(calls_as_caller),
        "calls_received": len(calls_as_receiver),
        "status_counts": status_counts
    }