"""
Redis manager for real-time features
"""
import redis
import json
import os
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta
import asyncio

class RedisManager:
    """Manager for Redis operations"""
    
    _instance = None
    _redis_client = None
    
    # Redis keys
    ONLINE_USERS_KEY = "online_users"
    USER_STATUS_KEY = "user_status:{user_id}"
    TYPING_KEY = "typing:{conversation_id}:{user_id}"
    CALL_ROOM_KEY = "call_room:{call_id}"
    RANDOM_CALL_QUEUE = "random_call_queue"
    
    # Expiration times
    TYPING_EXPIRE = 5  # 5 seconds
    CALL_ROOM_EXPIRE = 3600  # 1 hour
    STATUS_EXPIRE = 300  # 5 minutes
    
    @classmethod
    async def initialize(cls):
        """Initialize Redis connection"""
        if cls._instance is None:
            cls._instance = cls()
            await cls._instance._connect()
    
    @classmethod
    def get_instance(cls):
        """Get singleton instance"""
        if cls._instance is None:
            raise Exception("RedisManager not initialized")
        return cls._instance
    
    async def _connect(self):
        """Connect to Redis"""
        try:
            redis_url = os.environ.get('REDIS_URL', 'redis://localhost:6379')
            self._redis_client = redis.from_url(
                redis_url,
                decode_responses=True
            )
            # Test connection
            await asyncio.to_thread(self._redis_client.ping)
            print("Connected to Redis")
        except Exception as e:
            print(f"Error connecting to Redis: {e}")
            # Use in-memory fallback if Redis is not available
            self._redis_client = None
    
    @classmethod
    async def close(cls):
        """Close Redis connection"""
        if cls._instance and cls._instance._redis_client:
            cls._instance._redis_client.close()
    
    async def set_user_online(self, user_id: str, status: str = "online"):
        """Set user online status"""
        try:
            if not self._redis_client:
                return
                
            # Add to online users set
            await asyncio.to_thread(
                self._redis_client.sadd,
                self.ONLINE_USERS_KEY,
                user_id
            )
            
            # Set user status
            status_key = self.USER_STATUS_KEY.format(user_id=user_id)
            status_data = {
                "status": status,
                "last_seen": datetime.utcnow().isoformat()
            }
            
            await asyncio.to_thread(
                self._redis_client.setex,
                status_key,
                self.STATUS_EXPIRE,
                json.dumps(status_data)
            )
            
        except Exception as e:
            print(f"Error setting user online: {e}")
    
    async def set_user_offline(self, user_id: str):
        """Set user offline status"""
        try:
            if not self._redis_client:
                return
                
            # Remove from online users set
            await asyncio.to_thread(
                self._redis_client.srem,
                self.ONLINE_USERS_KEY,
                user_id
            )
            
            # Update user status
            status_key = self.USER_STATUS_KEY.format(user_id=user_id)
            status_data = {
                "status": "offline",
                "last_seen": datetime.utcnow().isoformat()
            }
            
            await asyncio.to_thread(
                self._redis_client.setex,
                status_key,
                self.STATUS_EXPIRE,
                json.dumps(status_data)
            )
            
        except Exception as e:
            print(f"Error setting user offline: {e}")
    
    async def get_user_status(self, user_id: str) -> Dict[str, Any]:
        """Get user status"""
        try:
            if not self._redis_client:
                return {"status": "offline", "last_seen": None}
                
            status_key = self.USER_STATUS_KEY.format(user_id=user_id)
            status_data = await asyncio.to_thread(
                self._redis_client.get,
                status_key
            )
            
            if status_data:
                return json.loads(status_data)
            else:
                return {"status": "offline", "last_seen": None}
                
        except Exception as e:
            print(f"Error getting user status: {e}")
            return {"status": "offline", "last_seen": None}
    
    async def get_online_users(self) -> List[str]:
        """Get list of online users"""
        try:
            if not self._redis_client:
                return []
                
            users = await asyncio.to_thread(
                self._redis_client.smembers,
                self.ONLINE_USERS_KEY
            )
            
            return list(users)
            
        except Exception as e:
            print(f"Error getting online users: {e}")
            return []
    
    async def set_typing(self, conversation_id: str, user_id: str):
        """Set user typing indicator"""
        try:
            if not self._redis_client:
                return
                
            typing_key = self.TYPING_KEY.format(
                conversation_id=conversation_id,
                user_id=user_id
            )
            
            await asyncio.to_thread(
                self._redis_client.setex,
                typing_key,
                self.TYPING_EXPIRE,
                "1"
            )
            
        except Exception as e:
            print(f"Error setting typing: {e}")
    
    async def remove_typing(self, conversation_id: str, user_id: str):
        """Remove user typing indicator"""
        try:
            if not self._redis_client:
                return
                
            typing_key = self.TYPING_KEY.format(
                conversation_id=conversation_id,
                user_id=user_id
            )
            
            await asyncio.to_thread(
                self._redis_client.delete,
                typing_key
            )
            
        except Exception as e:
            print(f"Error removing typing: {e}")
    
    async def get_typing_users(self, conversation_id: str) -> List[str]:
        """Get users who are typing in a conversation"""
        try:
            if not self._redis_client:
                return []
                
            pattern = self.TYPING_KEY.format(
                conversation_id=conversation_id,
                user_id="*"
            )
            
            keys = await asyncio.to_thread(
                self._redis_client.keys,
                pattern
            )
            
            # Extract user IDs from keys
            typing_users = []
            for key in keys:
                user_id = key.split(":")[-1]
                typing_users.append(user_id)
                
            return typing_users
            
        except Exception as e:
            print(f"Error getting typing users: {e}")
            return []
    
    async def create_call_room(self, call_id: str, room_data: dict):
        """Create a call room"""
        try:
            if not self._redis_client:
                return
                
            room_key = self.CALL_ROOM_KEY.format(call_id=call_id)
            
            await asyncio.to_thread(
                self._redis_client.setex,
                room_key,
                self.CALL_ROOM_EXPIRE,
                json.dumps(room_data)
            )
            
        except Exception as e:
            print(f"Error creating call room: {e}")
    
    async def get_call_room(self, call_id: str) -> Optional[dict]:
        """Get call room data"""
        try:
            if not self._redis_client:
                return None
                
            room_key = self.CALL_ROOM_KEY.format(call_id=call_id)
            room_data = await asyncio.to_thread(
                self._redis_client.get,
                room_key
            )
            
            if room_data:
                return json.loads(room_data)
            else:
                return None
                
        except Exception as e:
            print(f"Error getting call room: {e}")
            return None
    
    async def update_call_room(self, call_id: str, update_data: dict):
        """Update call room data"""
        try:
            if not self._redis_client:
                return
                
            room_key = self.CALL_ROOM_KEY.format(call_id=call_id)
            room_data = await self.get_call_room(call_id)
            
            if room_data:
                room_data.update(update_data)
                
                await asyncio.to_thread(
                    self._redis_client.setex,
                    room_key,
                    self.CALL_ROOM_EXPIRE,
                    json.dumps(room_data)
                )
                
        except Exception as e:
            print(f"Error updating call room: {e}")
    
    async def delete_call_room(self, call_id: str):
        """Delete call room"""
        try:
            if not self._redis_client:
                return
                
            room_key = self.CALL_ROOM_KEY.format(call_id=call_id)
            
            await asyncio.to_thread(
                self._redis_client.delete,
                room_key
            )
            
        except Exception as e:
            print(f"Error deleting call room: {e}")
    
    async def add_to_random_call_queue(self, user_id: str, preferences: dict):
        """Add user to random call queue"""
        try:
            if not self._redis_client:
                return
                
            queue_data = {
                "user_id": user_id,
                "preferences": preferences,
                "timestamp": datetime.utcnow().isoformat()
            }
            
            await asyncio.to_thread(
                self._redis_client.lpush,
                self.RANDOM_CALL_QUEUE,
                json.dumps(queue_data)
            )
            
        except Exception as e:
            print(f"Error adding to random call queue: {e}")
    
    async def find_random_call_match(self, user_id: str, preferences: dict) -> Optional[dict]:
        """Find a match in random call queue"""
        try:
            if not self._redis_client:
                return None
                
            # Get all users in queue
            queue_length = await asyncio.to_thread(
                self._redis_client.llen,
                self.RANDOM_CALL_QUEUE
            )
            
            for i in range(queue_length):
                queue_item = await asyncio.to_thread(
                    self._redis_client.lindex,
                    self.RANDOM_CALL_QUEUE,
                    i
                )
                
                if queue_item:
                    user_data = json.loads(queue_item)
                    
                    # Skip self
                    if user_data["user_id"] == user_id:
                        continue
                    
                    # Check if matches preferences
                    if self._check_call_compatibility(preferences, user_data["preferences"]):
                        # Remove from queue
                        await asyncio.to_thread(
                            self._redis_client.lrem,
                            self.RANDOM_CALL_QUEUE,
                            1,
                            queue_item
                        )
                        
                        return user_data
                        
            return None
            
        except Exception as e:
            print(f"Error finding random call match: {e}")
            return None
    
    def _check_call_compatibility(self, pref1: dict, pref2: dict) -> bool:
        """Check if two users' preferences are compatible"""
        # Check location compatibility
        if pref1.get("location") != pref2.get("location"):
            # If either user specified "global", allow match
            if pref1.get("location") != "global" and pref2.get("location") != "global":
                return False
        
        # Check gender compatibility
        if pref1.get("gender") and pref2.get("gender"):
            if pref1["gender"] != "all" and pref2["gender"] != "all":
                # Both have specific gender preferences
                # This would need more complex logic based on user genders
                pass
        
        return True
    
    async def remove_from_random_call_queue(self, user_id: str):
        """Remove user from random call queue"""
        try:
            if not self._redis_client:
                return
                
            # Get all items in queue
            queue_items = await asyncio.to_thread(
                self._redis_client.lrange,
                self.RANDOM_CALL_QUEUE,
                0,
                -1
            )
            
            # Remove items matching user_id
            for item in queue_items:
                user_data = json.loads(item)
                if user_data["user_id"] == user_id:
                    await asyncio.to_thread(
                        self._redis_client.lrem,
                        self.RANDOM_CALL_QUEUE,
                        0,
                        item
                    )
                    
        except Exception as e:
            print(f"Error removing from random call queue: {e}")
    
    # Cache operations
    async def cache_set(self, key: str, value: Any, expire: int = 300):
        """Set cache value"""
        try:
            if not self._redis_client:
                return
                
            await asyncio.to_thread(
                self._redis_client.setex,
                f"cache:{key}",
                expire,
                json.dumps(value)
            )
            
        except Exception as e:
            print(f"Error setting cache: {e}")
    
    async def cache_get(self, key: str) -> Any:
        """Get cache value"""
        try:
            if not self._redis_client:
                return None
                
            value = await asyncio.to_thread(
                self._redis_client.get,
                f"cache:{key}"
            )
            
            if value:
                return json.loads(value)
            else:
                return None
                
        except Exception as e:
            print(f"Error getting cache: {e}")
            return None
    
    async def cache_delete(self, key: str):
        """Delete cache value"""
        try:
            if not self._redis_client:
                return
                
            await asyncio.to_thread(
                self._redis_client.delete,
                f"cache:{key}"
            )
            
        except Exception as e:
            print(f"Error deleting cache: {e}")