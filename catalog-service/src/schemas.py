from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime


class ProductBase(BaseModel):
    """Base product schema."""
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    price: float = Field(..., gt=0)
    category: str = Field(..., min_length=1, max_length=50)
    image_url: Optional[str] = None
    stock: int = Field(default=0, ge=0)
    
    @validator('category')
    def validate_category(cls, v):
        """Validate category is one of the allowed values."""
        allowed_categories = ['food', 'toys', 'accessories', 'beds']
        if v.lower() not in allowed_categories:
            raise ValueError(f'Category must be one of: {", ".join(allowed_categories)}')
        return v.lower()


class ProductCreate(ProductBase):
    """Schema for creating a product."""
    pass


class ProductResponse(ProductBase):
    """Schema for product response."""
    id: str
    created_at: datetime
    
    class Config:
        from_attributes = True
