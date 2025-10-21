from sqlalchemy import Column, String, Float, Integer, DateTime
from sqlalchemy.sql import func
from datetime import datetime
import uuid

from .database import Base


class Product(Base):
    """Product model for the catalog."""
    
    __tablename__ = "products"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String(255), nullable=False)
    description = Column(String, nullable=True)
    price = Column(Float, nullable=False)
    category = Column(String(50), nullable=False)
    image_url = Column(String(500), nullable=True)
    stock = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, server_default=func.now())
    
    def to_dict(self):
        """Convert model to dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "price": self.price,
            "category": self.category,
            "image_url": self.image_url,
            "stock": self.stock,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }
