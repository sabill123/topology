"""
Chat and messaging models
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class MessageType(str, Enum):
    text = "text"
    image = "image"
    video = "video"
    voice = "voice"
    file = "file"
    system = "system"

class MessageStatus(str, Enum):
    sent = "sent"
    delivered = "delivered"
    read = "read"
    failed = "failed"

class Message(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    content: str
    message_type: MessageType = MessageType.text
    status: MessageStatus = MessageStatus.sent
    created_at: datetime
    updated_at: Optional[datetime] = None
    read_at: Optional[datetime] = None
    deleted_at: Optional[datetime] = None

class MessageCreate(BaseModel):
    receiver_id: str
    content: str = Field(..., min_length=1, max_length=1000)
    message_type: MessageType = MessageType.text

class MessageUpdate(BaseModel):
    status: Optional[MessageStatus] = None
    read_at: Optional[datetime] = None

class Conversation(BaseModel):
    id: str
    user1_id: str
    user2_id: str
    last_message_id: Optional[str] = None
    last_message_time: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class ConversationWithLastMessage(BaseModel):
    conversation: Conversation
    last_message: Optional[Message] = None
    other_user: "User"
    unread_count: int = 0

class ChatListResponse(BaseModel):
    conversations: List[ConversationWithLastMessage]
    total: int
    page: int
    page_size: int

class MessageListResponse(BaseModel):
    messages: List[Message]
    total: int
    page: int
    page_size: int

class TypingIndicator(BaseModel):
    user_id: str
    conversation_id: str
    is_typing: bool

# Legacy models for compatibility
class Chat(BaseModel):
    """Chat conversation model"""
    id: str
    user1_id: str
    user2_id: str
    last_message_id: Optional[str] = None
    last_message_time: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class ChatMessage(BaseModel):
    """Chat message model"""
    message_id: str
    chat_id: str
    sender_id: str
    content: str
    message_type: MessageType = MessageType.text
    is_read: bool = False
    created_at: datetime
    read_at: Optional[datetime] = None

class ChatOut(BaseModel):
    """Chat output model"""
    chat_id: str
    other_user_id: str
    other_user_info: Optional[dict] = None
    last_message: Optional[dict] = None
    unread_count: int = 0
    created_at: datetime
    updated_at: datetime

class ChatMessageOut(BaseModel):
    """Chat message output model"""
    message_id: str
    sender_id: str
    content: str
    is_read: bool
    created_at: datetime
    
from models.user import User
ConversationWithLastMessage.model_rebuild()