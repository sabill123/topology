"""
Store and virtual goods models
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class ItemCategory(str, Enum):
    filter = "filter"
    gift = "gift"
    vip = "vip"
    gems = "gems"

# Alias for compatibility
StoreCategory = ItemCategory

class ItemType(str, Enum):
    consumable = "consumable"
    permanent = "permanent"
    subscription = "subscription"

class StoreItem(BaseModel):
    id: str
    name: str
    description: str
    category: ItemCategory
    item_type: ItemType
    price: int  # Price in gems
    icon_url: Optional[str] = None
    is_active: bool = True
    is_premium: bool = False
    duration_days: Optional[int] = None  # For subscription items
    created_at: datetime
    updated_at: datetime

class UserItem(BaseModel):
    id: str
    user_id: str
    item_id: str
    quantity: int = 1
    purchased_at: datetime
    expires_at: Optional[datetime] = None
    is_active: bool = True

# Legacy models for compatibility
class Purchase(BaseModel):
    """Purchase model"""
    purchase_id: str
    user_id: str
    item_id: str
    quantity: int
    unit_price: float
    total_price: float
    status: str
    created_at: datetime

class PurchaseCreate(BaseModel):
    """Purchase creation model"""
    item_id: str
    quantity: int = 1

class PurchaseRequest(BaseModel):
    item_id: str
    quantity: int = 1

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    user_item: Optional[UserItem] = None
    remaining_gems: int

class GiftRequest(BaseModel):
    receiver_id: str
    item_id: str
    message: Optional[str] = Field(None, max_length=200)

class GiftResponse(BaseModel):
    success: bool
    message: str
    gift_id: str
    remaining_gems: int

class UserInventory(BaseModel):
    items: List[UserItem]
    total: int
    
class StoreItemListResponse(BaseModel):
    items: List[StoreItem]
    total: int
    page: int
    page_size: int

class TransactionHistory(BaseModel):
    id: str
    user_id: str
    transaction_type: str  # "purchase", "gift_sent", "gift_received", "earned"
    amount: int
    item_id: Optional[str] = None
    description: str
    created_at: datetime

class TransactionListResponse(BaseModel):
    transactions: List[TransactionHistory]
    total: int
    page: int
    page_size: int