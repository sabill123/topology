"""
WebSocket connection manager
"""
from typing import List, Dict, Set
from fastapi import WebSocket
import json
import asyncio
from datetime import datetime

class ConnectionManager:
    """Manager for WebSocket connections"""
    
    def __init__(self):
        # Active connections: {user_id: WebSocket}
        self.active_connections: Dict[str, WebSocket] = {}
        # User rooms: {room_id: Set[user_id]}
        self.rooms: Dict[str, Set[str]] = {}
        # User to room mapping: {user_id: Set[room_id]}
        self.user_rooms: Dict[str, Set[str]] = {}
    
    async def connect(self, websocket: WebSocket, user_id: str):
        """Accept WebSocket connection"""
        await websocket.accept()
        self.active_connections[user_id] = websocket
        
        # Initialize user room set
        if user_id not in self.user_rooms:
            self.user_rooms[user_id] = set()
    
    def disconnect(self, user_id: str):
        """Remove WebSocket connection"""
        if user_id in self.active_connections:
            del self.active_connections[user_id]
        
        # Remove user from all rooms
        if user_id in self.user_rooms:
            for room_id in self.user_rooms[user_id]:
                if room_id in self.rooms:
                    self.rooms[room_id].discard(user_id)
                    # Remove empty rooms
                    if not self.rooms[room_id]:
                        del self.rooms[room_id]
            
            del self.user_rooms[user_id]
    
    async def send_personal_message(self, message: dict, user_id: str):
        """Send message to specific user"""
        if user_id in self.active_connections:
            websocket = self.active_connections[user_id]
            try:
                await websocket.send_json(message)
            except Exception as e:
                print(f"Error sending message to {user_id}: {e}")
                self.disconnect(user_id)
    
    async def broadcast(self, message: dict, exclude_user: str = None):
        """Broadcast message to all connected users"""
        disconnected_users = []
        
        for user_id, websocket in self.active_connections.items():
            if user_id != exclude_user:
                try:
                    await websocket.send_json(message)
                except Exception as e:
                    print(f"Error broadcasting to {user_id}: {e}")
                    disconnected_users.append(user_id)
        
        # Clean up disconnected users
        for user_id in disconnected_users:
            self.disconnect(user_id)
    
    def join_room(self, user_id: str, room_id: str):
        """Add user to room"""
        if room_id not in self.rooms:
            self.rooms[room_id] = set()
        
        self.rooms[room_id].add(user_id)
        
        if user_id not in self.user_rooms:
            self.user_rooms[user_id] = set()
        
        self.user_rooms[user_id].add(room_id)
    
    def leave_room(self, user_id: str, room_id: str):
        """Remove user from room"""
        if room_id in self.rooms:
            self.rooms[room_id].discard(user_id)
            # Remove empty rooms
            if not self.rooms[room_id]:
                del self.rooms[room_id]
        
        if user_id in self.user_rooms:
            self.user_rooms[user_id].discard(room_id)
    
    async def send_to_room(self, message: dict, room_id: str, exclude_user: str = None):
        """Send message to all users in room"""
        if room_id not in self.rooms:
            return
        
        disconnected_users = []
        
        for user_id in self.rooms[room_id]:
            if user_id != exclude_user and user_id in self.active_connections:
                try:
                    await self.active_connections[user_id].send_json(message)
                except Exception as e:
                    print(f"Error sending to {user_id} in room {room_id}: {e}")
                    disconnected_users.append(user_id)
        
        # Clean up disconnected users
        for user_id in disconnected_users:
            self.disconnect(user_id)
    
    def get_room_users(self, room_id: str) -> List[str]:
        """Get list of users in room"""
        if room_id in self.rooms:
            return list(self.rooms[room_id])
        return []
    
    def get_user_rooms(self, user_id: str) -> List[str]:
        """Get list of rooms user is in"""
        if user_id in self.user_rooms:
            return list(self.user_rooms[user_id])
        return []
    
    def is_user_online(self, user_id: str) -> bool:
        """Check if user is online"""
        return user_id in self.active_connections
    
    async def handle_message(self, websocket: WebSocket, user_id: str, message: dict):
        """Handle incoming WebSocket message"""
        message_type = message.get("type")
        data = message.get("data", {})
        
        if message_type == "ping":
            # Respond to ping
            await self.send_personal_message({
                "type": "pong",
                "timestamp": datetime.utcnow().isoformat()
            }, user_id)
        
        elif message_type == "join_room":
            room_id = data.get("room_id")
            if room_id:
                self.join_room(user_id, room_id)
                
                # Notify room members
                await self.send_to_room({
                    "type": "user_joined",
                    "data": {
                        "user_id": user_id,
                        "room_id": room_id,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, room_id, exclude_user=user_id)
        
        elif message_type == "leave_room":
            room_id = data.get("room_id")
            if room_id:
                self.leave_room(user_id, room_id)
                
                # Notify room members
                await self.send_to_room({
                    "type": "user_left",
                    "data": {
                        "user_id": user_id,
                        "room_id": room_id,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, room_id)
        
        elif message_type == "room_message":
            room_id = data.get("room_id")
            if room_id and room_id in self.user_rooms.get(user_id, []):
                # Forward message to room
                await self.send_to_room({
                    "type": "room_message",
                    "data": {
                        "user_id": user_id,
                        "room_id": room_id,
                        "message": data.get("message"),
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, room_id, exclude_user=user_id)
        
        elif message_type == "private_message":
            target_user_id = data.get("target_user_id")
            if target_user_id:
                # Forward message to target user
                await self.send_personal_message({
                    "type": "private_message",
                    "data": {
                        "from_user_id": user_id,
                        "message": data.get("message"),
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, target_user_id)
        
        elif message_type == "typing":
            conversation_id = data.get("conversation_id")
            is_typing = data.get("is_typing", False)
            
            # Handle typing indicator
            from app.utils.redis_manager import RedisManager
            redis = RedisManager.get_instance()
            
            if is_typing:
                await redis.set_typing(conversation_id, user_id)
            else:
                await redis.remove_typing(conversation_id, user_id)
            
            # Notify the other user in conversation
            other_user_id = data.get("other_user_id")
            if other_user_id:
                await self.send_personal_message({
                    "type": "typing",
                    "data": {
                        "user_id": user_id,
                        "conversation_id": conversation_id,
                        "is_typing": is_typing,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, other_user_id)
        
        elif message_type == "call_signal":
            # Handle WebRTC signaling
            target_user_id = data.get("target_user_id")
            signal_type = data.get("signal_type")
            signal_data = data.get("signal_data")
            
            if target_user_id and signal_type and signal_data:
                await self.send_personal_message({
                    "type": "call_signal",
                    "data": {
                        "from_user_id": user_id,
                        "signal_type": signal_type,
                        "signal_data": signal_data,
                        "timestamp": datetime.utcnow().isoformat()
                    }
                }, target_user_id)
        
        else:
            # Unknown message type
            await self.send_personal_message({
                "type": "error",
                "data": {
                    "message": f"Unknown message type: {message_type}",
                    "timestamp": datetime.utcnow().isoformat()
                }
            }, user_id)

# Global connection manager instance
manager = ConnectionManager()