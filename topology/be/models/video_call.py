"""
Video call models
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class CallType(str, Enum):
    video = "video"
    voice = "voice"

class CallStatus(str, Enum):
    ringing = "ringing"
    connected = "connected"
    ended = "ended"
    missed = "missed"
    declined = "declined"
    failed = "failed"

class CallRecord(BaseModel):
    id: str
    caller_id: str
    receiver_id: str
    call_type: CallType
    status: CallStatus
    duration: Optional[int] = None  # Duration in seconds
    started_at: datetime
    connected_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: datetime

class CallRecordWithUser(BaseModel):
    call: CallRecord
    other_user: "User"
    is_incoming: bool

class CallListResponse(BaseModel):
    calls: List[CallRecordWithUser]
    total: int
    page: int
    page_size: int

class CallInitiateRequest(BaseModel):
    receiver_id: str
    call_type: CallType = CallType.video

class CallAnswerRequest(BaseModel):
    call_id: str
    sdp_answer: str

class CallOfferRequest(BaseModel):
    call_id: str
    sdp_offer: str

class IceCandidateRequest(BaseModel):
    call_id: str
    candidate: str

class CallEndRequest(BaseModel):
    call_id: str

class CallSignal(BaseModel):
    type: str  # "offer", "answer", "ice-candidate"
    data: dict

# Legacy models for compatibility  
class VideoCall(BaseModel):
    """Video call model"""
    call_id: str
    caller_id: str
    receiver_id: str
    call_type: CallType = CallType.video
    status: CallStatus
    room_id: Optional[str] = None
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration: Optional[int] = None
    created_at: datetime

class VideoCallCreate(BaseModel):
    """Video call creation model"""
    receiver_id: str
    call_type: CallType = CallType.video

class VideoCallUpdate(BaseModel):
    """Video call update model"""
    status: Optional[CallStatus] = None
    room_id: Optional[str] = None
    ended_at: Optional[datetime] = None

from models.user import User
CallRecordWithUser.model_rebuild()