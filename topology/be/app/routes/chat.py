"""
Chat routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models.chat import Chat, ChatMessage, ChatOut, ChatMessageOut
from app.utils.auth import get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager
from app.utils.websocket_manager import ConnectionManager
import uuid
from datetime import datetime

router = APIRouter(
    prefix="/chats",
    tags=["chats"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()
redis_manager = RedisManager()
ws_manager = ConnectionManager()

@router.get("/", response_model=List[ChatOut])
async def get_chats(
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Get all chats for current user."""
    # Get chats where user is either sender or receiver
    sent_chats = await db.query_items(
        "chats",
        {"sender_id": current_user["user_id"]}
    )
    
    received_chats = await db.query_items(
        "chats",
        {"receiver_id": current_user["user_id"]}
    )
    
    # Combine and group by conversation
    conversations = {}
    
    for chat in sent_chats + received_chats:
        # Create conversation key (sorted user IDs)
        user_ids = sorted([chat["sender_id"], chat["receiver_id"]])
        conv_key = f"{user_ids[0]}_{user_ids[1]}"
        
        # Get the other user ID
        other_user_id = chat["receiver_id"] if chat["sender_id"] == current_user["user_id"] else chat["sender_id"]
        
        # Update conversation info with latest message
        if conv_key not in conversations or chat["created_at"] > conversations[conv_key]["last_message"]["created_at"]:
            # Get other user details
            other_user = await db.get_item("users", other_user_id)
            
            if other_user:
                conversations[conv_key] = {
                    "conversation_id": conv_key,
                    "user": {
                        "user_id": other_user["user_id"],
                        "username": other_user["username"],
                        "display_name": other_user["display_name"],
                        "profile_photo": other_user.get("profile_photo")
                    },
                    "last_message": {
                        "message_id": chat["message_id"],
                        "content": chat["content"],
                        "is_read": chat["is_read"],
                        "created_at": chat["created_at"],
                        "is_sent": chat["sender_id"] == current_user["user_id"]
                    },
                    "unread_count": 0,
                    "is_online": await redis_manager.is_user_online(other_user_id)
                }
    
    # Count unread messages
    for conv_key, conv in conversations.items():
        other_user_id = conv["user"]["user_id"]
        unread_messages = await db.query_items(
            "chats",
            {
                "sender_id": other_user_id,
                "receiver_id": current_user["user_id"],
                "is_read": False
            }
        )
        conv["unread_count"] = len(unread_messages)
    
    # Sort by last message time and paginate
    sorted_conversations = sorted(
        conversations.values(),
        key=lambda x: x["last_message"]["created_at"],
        reverse=True
    )
    
    return sorted_conversations[offset:offset + limit]

@router.get("/{user_id}/messages", response_model=List[ChatMessageOut])
async def get_chat_messages(
    user_id: str,
    current_user: dict = Depends(get_current_user_from_token),
    limit: int = Query(50, ge=1, le=200),
    before: str = Query(None)
) -> Any:
    """Get chat messages with a specific user."""
    # Check if user exists
    other_user = await db.get_item("users", user_id)
    if not other_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get messages between the two users
    filters = {}
    if before:
        # Add before filter for pagination
        filters["created_at"] = {"$lt": before}
    
    sent_messages = await db.query_items(
        "chats",
        {
            **filters,
            "sender_id": current_user["user_id"],
            "receiver_id": user_id
        }
    )
    
    received_messages = await db.query_items(
        "chats",
        {
            **filters,
            "sender_id": user_id,
            "receiver_id": current_user["user_id"]
        }
    )
    
    # Combine and sort messages
    all_messages = sent_messages + received_messages
    all_messages.sort(key=lambda x: x["created_at"], reverse=True)
    
    # Apply limit
    messages = all_messages[:limit]
    
    # Format messages
    message_outs = []
    for msg in messages:
        message_outs.append(ChatMessageOut(
            message_id=msg["message_id"],
            sender_id=msg["sender_id"],
            receiver_id=msg["receiver_id"],
            content=msg["content"],
            is_read=msg["is_read"],
            created_at=msg["created_at"],
            is_sent=msg["sender_id"] == current_user["user_id"]
        ))
    
    # Mark received messages as read
    unread_received = [msg for msg in received_messages if not msg["is_read"]]
    for msg in unread_received:
        await db.update_item(
            "chats",
            msg["message_id"],
            {"is_read": True, "read_at": db._get_current_time()}
        )
    
    # Send read receipt via WebSocket
    if unread_received and await redis_manager.is_user_online(user_id):
        await ws_manager.send_notification(
            user_id,
            {
                "type": "messages_read",
                "reader_id": current_user["user_id"],
                "message_ids": [msg["message_id"] for msg in unread_received]
            }
        )
    
    return message_outs

@router.post("/{user_id}/messages", response_model=ChatMessageOut)
async def send_message(
    user_id: str,
    message: ChatMessage,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Send a message to a user."""
    # Check if receiver exists
    receiver = await db.get_item("users", user_id)
    if not receiver:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receiver not found"
        )
    
    # Create new message
    message_id = str(uuid.uuid4())
    new_message = {
        "message_id": message_id,
        "sender_id": current_user["user_id"],
        "receiver_id": user_id,
        "content": message.content,
        "is_read": False,
        "created_at": db._get_current_time()
    }
    
    await db.create_item("chats", new_message)
    
    # Send message via WebSocket if receiver is online
    if await redis_manager.is_user_online(user_id):
        await ws_manager.send_message(
            user_id,
            {
                "type": "new_message",
                "message": {
                    "message_id": message_id,
                    "sender": {
                        "user_id": current_user["user_id"],
                        "username": current_user["username"],
                        "display_name": current_user["display_name"],
                        "profile_photo": current_user.get("profile_photo")
                    },
                    "content": message.content,
                    "created_at": new_message["created_at"]
                }
            }
        )
    
    return ChatMessageOut(
        message_id=message_id,
        sender_id=current_user["user_id"],
        receiver_id=user_id,
        content=message.content,
        is_read=False,
        created_at=new_message["created_at"],
        is_sent=True
    )

@router.put("/messages/{message_id}/read")
async def mark_message_read(
    message_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Mark a message as read."""
    # Get message
    message = await db.get_item("chats", message_id)
    
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found"
        )
    
    # Check if current user is the receiver
    if message["receiver_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only mark messages sent to you as read"
        )
    
    # Mark as read
    if not message["is_read"]:
        await db.update_item(
            "chats",
            message_id,
            {
                "is_read": True,
                "read_at": db._get_current_time()
            }
        )
        
        # Send read receipt via WebSocket
        if await redis_manager.is_user_online(message["sender_id"]):
            await ws_manager.send_notification(
                message["sender_id"],
                {
                    "type": "message_read",
                    "reader_id": current_user["user_id"],
                    "message_id": message_id
                }
            )
    
    return {"message": "Message marked as read"}

@router.delete("/messages/{message_id}")
async def delete_message(
    message_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Delete a message (only for sender)."""
    # Get message
    message = await db.get_item("chats", message_id)
    
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message not found"
        )
    
    # Check if current user is the sender
    if message["sender_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete messages you sent"
        )
    
    # Delete message
    await db.delete_item("chats", message_id)
    
    # Send notification via WebSocket
    if await redis_manager.is_user_online(message["receiver_id"]):
        await ws_manager.send_notification(
            message["receiver_id"],
            {
                "type": "message_deleted",
                "message_id": message_id,
                "sender_id": current_user["user_id"]
            }
        )
    
    return {"message": "Message deleted successfully"}

@router.get("/unread/count")
async def get_unread_count(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get total unread message count."""
    unread_messages = await db.query_items(
        "chats",
        {
            "receiver_id": current_user["user_id"],
            "is_read": False
        }
    )
    
    return {"unread_count": len(unread_messages)}

@router.post("/{user_id}/typing")
async def send_typing_indicator(
    user_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Send typing indicator to a user."""
    # Check if receiver is online
    if await redis_manager.is_user_online(user_id):
        await ws_manager.send_notification(
            user_id,
            {
                "type": "typing",
                "user_id": current_user["user_id"],
                "username": current_user["username"]
            }
        )
    
    return {"message": "Typing indicator sent"}