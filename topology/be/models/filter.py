"""
Filter data models
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from models.user import Gender

class AgeRange(BaseModel):
    min: Optional[int] = Field(None, ge=18, le=100)
    max: Optional[int] = Field(None, ge=18, le=100)

class FilterBase(BaseModel):
    """Base filter model"""
    name: str = Field(..., min_length=1, max_length=50)
    age_range: Optional[AgeRange] = None
    genders: Optional[List[Gender]] = None
    countries: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    languages: Optional[List[str]] = None
    only_online: bool = False
    only_verified: bool = False

class FilterCreate(FilterBase):
    """Create filter model"""
    pass

class FilterUpdate(BaseModel):
    """Update filter model"""
    name: Optional[str] = Field(None, min_length=1, max_length=50)
    age_range: Optional[AgeRange] = None
    genders: Optional[List[Gender]] = None
    countries: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    languages: Optional[List[str]] = None
    only_online: Optional[bool] = None
    only_verified: Optional[bool] = None
    is_active: Optional[bool] = None

class Filter(FilterBase):
    """Filter response model"""
    filter_id: str
    user_id: str
    is_active: bool = True
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True