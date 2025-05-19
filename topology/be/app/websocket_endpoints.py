"""
WebSocket endpoints for real-time features
"""
from fastapi import WebSocket, WebSocketDisconnect, Depends, Query
from app.utils.auth import verify_websocket_token
from app.utils.websocket_manager import ConnectionManager
from app.utils.redis_manager import RedisManager
from app.utils.google_sheets import GoogleSheetsManager
import json
import logging

logger = logging.getLogger(__name__)

# Initialize services
ws_manager = ConnectionManager()
redis_manager = RedisManager()
db = GoogleSheetsManager.get_instance()

async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(...),
):
    """Main WebSocket endpoint for real-time communication."""
    user_id = None
    
    try:
        # Verify token and get user
        user_id = await verify_websocket_token(token)
        if not user_id:
            await websocket.close(code=4001, reason="Invalid token")
            return
        
        # Accept connection
        await ws_manager.connect(user_id, websocket)
        
        # Set user online
        await redis_manager.set_user_online(user_id)
        
        # Update user status in database
        await db.update_item("users", user_id, {"status": "online"})
        
        # Send initial connection success message
        await websocket.send_json({
            "type": "connection_established",
            "user_id": user_id
        })
        
        # Listen for messages
        while True:
            try:
                # Receive message
                data = await websocket.receive_json()
                
                # Handle different message types
                await handle_websocket_message(user_id, data)
                
            except WebSocketDisconnect:
                logger.info(f"WebSocket disconnected for user {user_id}")
                break
            except json.JSONDecodeError:
                await websocket.send_json({
                    "type": "error",
                    "message": "Invalid JSON format"
                })
            except Exception as e:
                logger.error(f"Error handling WebSocket message: {e}")
                await websocket.send_json({
                    "type": "error",
                    "message": "Internal server error"
                })
    
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    
    finally:
        # Clean up on disconnect
        if user_id:
            await ws_manager.disconnect(user_id)
            await redis_manager.set_user_offline(user_id)
            await db.update_item("users", user_id, {"status": "offline"})

async def handle_websocket_message(user_id: str, data: dict):
    """Handle different types of WebSocket messages."""
    message_type = data.get("type")
    
    if message_type == "ping":
        # Simple ping/pong for connection keep-alive
        await ws_manager.send_personal_message(
            user_id,
            {"type": "pong", "timestamp": data.get("timestamp")}
        )
    
    elif message_type == "typing":
        # Typing indicator
        target_user_id = data.get("target_user_id")
        if target_user_id:
            await ws_manager.send_notification(
                target_user_id,
                {
                    "type": "user_typing",
                    "user_id": user_id,
                    "is_typing": data.get("is_typing", True)
                }
            )
    
    elif message_type == "message":
        # Chat message (real-time delivery)
        receiver_id = data.get("receiver_id")
        content = data.get("content")
        
        if receiver_id and content:
            # Get sender info
            sender = await db.get_item("users", user_id)
            
            if sender:
                # Send message to receiver if online
                await ws_manager.send_message(
                    receiver_id,
                    {
                        "type": "new_message",
                        "message": {
                            "sender": {
                                "user_id": user_id,
                                "username": sender["username"],
                                "display_name": sender["display_name"],
                                "profile_photo": sender.get("profile_photo")
                            },
                            "content": content,
                            "timestamp": db._get_current_time()
                        }
                    }
                )
    
    elif message_type == "call_signal":
        # WebRTC signaling for video calls
        call_id = data.get("call_id")
        target_user_id = data.get("target_user_id")
        signal_data = data.get("signal_data")
        
        if call_id and target_user_id and signal_data:
            await ws_manager.send_notification(
                target_user_id,
                {
                    "type": "call_signal",
                    "call_id": call_id,
                    "from_user_id": user_id,
                    "signal_data": signal_data
                }
            )
    
    elif message_type == "ice_candidate":
        # ICE candidate for WebRTC
        call_id = data.get("call_id")
        target_user_id = data.get("target_user_id")
        candidate = data.get("candidate")
        
        if call_id and target_user_id and candidate:
            await ws_manager.send_notification(
                target_user_id,
                {
                    "type": "ice_candidate",
                    "call_id": call_id,
                    "from_user_id": user_id,
                    "candidate": candidate
                }
            )
    
    elif message_type == "presence_query":
        # Query online status of specific users
        user_ids = data.get("user_ids", [])
        
        if user_ids:
            presence_data = {}
            for uid in user_ids:
                presence_data[uid] = await redis_manager.is_user_online(uid)
            
            await ws_manager.send_personal_message(
                user_id,
                {
                    "type": "presence_update",
                    "presence": presence_data
                }
            )
    
    elif message_type == "location_update":
        # Update user location (for location-based features)
        location = data.get("location")
        
        if location:
            # Update location in database
            await db.update_item(
                "users",
                user_id,
                {
                    "location": location,
                    "location_updated_at": db._get_current_time()
                }
            )
            
            # Store in Redis for real-time features
            await redis_manager.set(
                f"user_location:{user_id}",
                json.dumps(location),
                expire=3600  # 1 hour
            )
    
    elif message_type == "get_nearby_users":
        # Get users near current user's location
        max_distance = data.get("max_distance", 10)  # km
        
        # Get current user's location from Redis
        location_data = await redis_manager.get(f"user_location:{user_id}")
        
        if location_data:
            current_location = json.loads(location_data)
            
            # Get all online users
            online_users = await redis_manager.get_online_users()
            nearby_users = []
            
            for uid in online_users:
                if uid == user_id:
                    continue
                
                # Get user's location
                user_location_data = await redis_manager.get(f"user_location:{uid}")
                
                if user_location_data:
                    user_location = json.loads(user_location_data)
                    
                    # Calculate distance (simplified)
                    distance = calculate_distance(
                        current_location["lat"],
                        current_location["lng"],
                        user_location["lat"],
                        user_location["lng"]
                    )
                    
                    if distance <= max_distance:
                        # Get user info
                        user_info = await db.get_item("users", uid)
                        
                        if user_info:
                            nearby_users.append({
                                "user_id": uid,
                                "username": user_info["username"],
                                "display_name": user_info["display_name"],
                                "profile_photo": user_info.get("profile_photo"),
                                "distance": distance
                            })
            
            # Sort by distance
            nearby_users.sort(key=lambda x: x["distance"])
            
            await ws_manager.send_personal_message(
                user_id,
                {
                    "type": "nearby_users",
                    "users": nearby_users[:50]  # Limit to 50 users
                }
            )
    
    else:
        # Unknown message type
        await ws_manager.send_personal_message(
            user_id,
            {
                "type": "error",
                "message": f"Unknown message type: {message_type}"
            }
        )

def calculate_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate distance between two coordinates in kilometers (simplified)."""
    # Simplified distance calculation (Haversine formula)
    from math import radians, sin, cos, sqrt, atan2
    
    R = 6371  # Earth's radius in kilometers
    
    lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])
    
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlng/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return R * c