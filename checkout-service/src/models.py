from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from .database import Base


class Order(Base):
    """Order model for storing checkout orders."""
    __tablename__ = "orders"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, nullable=False, index=True)
    customer_email = Column(String, nullable=True)
    shipping_address = Column(String, nullable=True)
    total = Column(Float, nullable=False)
    status = Column(String, nullable=False, default="pending")  # pending, confirmed, failed
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship to order items
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    
    def to_dict(self):
        """Convert order to dictionary."""
        return {
            "id": self.id,
            "session_id": self.session_id,
            "customer_email": self.customer_email,
            "shipping_address": self.shipping_address,
            "total": self.total,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "items": [item.to_dict() for item in self.items]
        }


class OrderItem(Base):
    """Order item model for storing individual items in an order."""
    __tablename__ = "order_items"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    order_id = Column(String, ForeignKey("orders.id"), nullable=False)
    product_id = Column(String, nullable=False)
    product_name = Column(String, nullable=False)
    quantity = Column(Integer, nullable=False)
    price = Column(Float, nullable=False)
    
    # Relationship to order
    order = relationship("Order", back_populates="items")
    
    def to_dict(self):
        """Convert order item to dictionary."""
        return {
            "id": self.id,
            "product_id": self.product_id,
            "product_name": self.product_name,
            "quantity": self.quantity,
            "price": self.price
        }
