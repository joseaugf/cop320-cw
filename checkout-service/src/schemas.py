from pydantic import BaseModel, EmailStr, Field, validator
from typing import List, Optional
from datetime import datetime


class CheckoutItemRequest(BaseModel):
    """Schema for checkout item in request."""
    product_id: str
    product_name: str
    quantity: int = Field(gt=0, description="Quantity must be greater than 0")
    price: float = Field(gt=0, description="Price must be greater than 0")


class CheckoutRequest(BaseModel):
    """Schema for checkout request."""
    session_id: str = Field(min_length=1, description="Session ID is required")
    customer_email: Optional[EmailStr] = None
    shipping_address: Optional[str] = Field(None, max_length=500)
    items: Optional[List[CheckoutItemRequest]] = None
    
    @validator("session_id")
    def validate_session_id(cls, v):
        if not v or not v.strip():
            raise ValueError("Session ID cannot be empty")
        return v.strip()


class OrderItemResponse(BaseModel):
    """Schema for order item in response."""
    id: str
    product_id: str
    product_name: str
    quantity: int
    price: float


class OrderResponse(BaseModel):
    """Schema for order response."""
    id: str
    session_id: str
    customer_email: Optional[str]
    shipping_address: Optional[str]
    total: float
    status: str
    created_at: datetime
    items: List[OrderItemResponse]


class ErrorResponse(BaseModel):
    """Schema for error response."""
    error: dict
    
    class Config:
        json_schema_extra = {
            "example": {
                "error": {
                    "code": "CHECKOUT_FAILED",
                    "message": "Failed to process checkout",
                    "trace_id": "abc123...",
                    "timestamp": "2025-10-20T10:30:00Z"
                }
            }
        }
