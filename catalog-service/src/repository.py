"""Repository layer for product data access."""

from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import List, Optional
from opentelemetry import trace
import logging

from .models import Product
from .schemas import ProductCreate
from .failure_simulator import failure_simulator

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class ProductRepository:
    """Repository for product CRUD operations with observability."""
    
    def __init__(self, db: Session):
        self.db = db
    
    async def get_all(self, skip: int = 0, limit: int = 100) -> List[Product]:
        """
        Get all products with pagination.
        
        Args:
            skip: Number of records to skip
            limit: Maximum number of records to return
            
        Returns:
            List of products
        """
        with tracer.start_as_current_span("repository.get_all_products") as span:
            span.set_attribute("db.operation", "select")
            span.set_attribute("pagination.skip", skip)
            span.set_attribute("pagination.limit", limit)
            
            try:
                # Apply failure simulations
                await failure_simulator.check_and_apply_failures("get_all_products")
                
                # Execute query
                products = self.db.query(Product).offset(skip).limit(limit).all()
                
                span.set_attribute("result.count", len(products))
                logger.info(f"Retrieved {len(products)} products")
                
                return products
                
            except Exception as e:
                span.set_attribute("error", True)
                span.record_exception(e)
                logger.error(f"Error retrieving products: {e}")
                raise
    
    async def get_by_id(self, product_id: str) -> Optional[Product]:
        """
        Get a product by ID.
        
        Args:
            product_id: Product ID
            
        Returns:
            Product or None if not found
        """
        with tracer.start_as_current_span("repository.get_product_by_id") as span:
            span.set_attribute("db.operation", "select")
            span.set_attribute("product.id", product_id)
            
            try:
                # Apply failure simulations
                await failure_simulator.check_and_apply_failures("get_product_by_id")
                
                # Execute query
                product = self.db.query(Product).filter(Product.id == product_id).first()
                
                if product:
                    span.set_attribute("result.found", True)
                    logger.info(f"Found product: {product_id}")
                else:
                    span.set_attribute("result.found", False)
                    logger.warning(f"Product not found: {product_id}")
                
                return product
                
            except Exception as e:
                span.set_attribute("error", True)
                span.record_exception(e)
                logger.error(f"Error retrieving product {product_id}: {e}")
                raise
    
    async def search(
        self, 
        query: Optional[str] = None, 
        category: Optional[str] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[Product]:
        """
        Search products by query and/or category.
        
        Args:
            query: Search query for name/description
            category: Filter by category
            skip: Number of records to skip
            limit: Maximum number of records to return
            
        Returns:
            List of matching products
        """
        with tracer.start_as_current_span("repository.search_products") as span:
            span.set_attribute("db.operation", "select")
            span.set_attribute("search.query", query or "")
            span.set_attribute("search.category", category or "")
            span.set_attribute("pagination.skip", skip)
            span.set_attribute("pagination.limit", limit)
            
            try:
                # Apply failure simulations
                await failure_simulator.check_and_apply_failures("search_products")
                
                # Build query
                db_query = self.db.query(Product)
                
                # Apply search filter
                if query:
                    search_filter = or_(
                        Product.name.ilike(f"%{query}%"),
                        Product.description.ilike(f"%{query}%")
                    )
                    db_query = db_query.filter(search_filter)
                
                # Apply category filter
                if category:
                    db_query = db_query.filter(Product.category == category.lower())
                
                # Execute query with pagination
                products = db_query.offset(skip).limit(limit).all()
                
                span.set_attribute("result.count", len(products))
                logger.info(f"Search returned {len(products)} products")
                
                return products
                
            except Exception as e:
                span.set_attribute("error", True)
                span.record_exception(e)
                logger.error(f"Error searching products: {e}")
                raise
    
    async def create(self, product_data: ProductCreate) -> Product:
        """
        Create a new product.
        
        Args:
            product_data: Product data
            
        Returns:
            Created product
        """
        with tracer.start_as_current_span("repository.create_product") as span:
            span.set_attribute("db.operation", "insert")
            
            try:
                # Apply failure simulations
                await failure_simulator.check_and_apply_failures("create_product")
                
                # Create product
                product = Product(**product_data.model_dump())
                self.db.add(product)
                self.db.commit()
                self.db.refresh(product)
                
                span.set_attribute("product.id", product.id)
                logger.info(f"Created product: {product.id}")
                
                return product
                
            except Exception as e:
                self.db.rollback()
                span.set_attribute("error", True)
                span.record_exception(e)
                logger.error(f"Error creating product: {e}")
                raise
