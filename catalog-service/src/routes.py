"""API routes for the catalog service."""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from opentelemetry import trace
import logging

from .database import get_db
from .repository import ProductRepository
from .schemas import ProductResponse
from .failure_simulator import SimulatedError
from .metrics import catalog_metrics
from .chaos_simulator import chaos_simulator
from .feature_flag_client import feature_flag_client

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)

router = APIRouter(prefix="/api", tags=["products"])


@router.get("/products", response_model=List[ProductResponse])
async def get_products(
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=500, description="Maximum number of records to return"),
    db: Session = Depends(get_db)
):
    """
    Get all products with pagination.
    
    Args:
        skip: Number of records to skip (default: 0)
        limit: Maximum number of records to return (default: 100, max: 500)
        db: Database session
        
    Returns:
        List of products
    """
    with tracer.start_as_current_span("api.get_products") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/products")
        span.set_attribute("pagination.skip", skip)
        span.set_attribute("pagination.limit", limit)
        
        try:
            # Check for chaos engineering simulations
            await chaos_simulator.check_and_apply_chaos("catalog-service", feature_flag_client)
            
            repo = ProductRepository(db)
            products = await repo.get_all(skip=skip, limit=limit)
            
            span.set_attribute("response.count", len(products))
            logger.info(f"GET /api/products - Returned {len(products)} products")
            
            return products
            
        except SimulatedError as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Simulated error in get_products: {e}")
            raise HTTPException(status_code=503, detail=str(e))
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Error in get_products: {e}")
            raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/products/{product_id}", response_model=ProductResponse)
async def get_product(
    product_id: str,
    db: Session = Depends(get_db)
):
    """
    Get a specific product by ID.
    
    Args:
        product_id: Product ID
        db: Database session
        
    Returns:
        Product details
        
    Raises:
        HTTPException: 404 if product not found
    """
    with tracer.start_as_current_span("api.get_product") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/products/{id}")
        span.set_attribute("product.id", product_id)
        
        try:
            # Check for chaos engineering simulations
            await chaos_simulator.check_and_apply_chaos("catalog-service", feature_flag_client)
            
            repo = ProductRepository(db)
            product = await repo.get_by_id(product_id)
            
            if not product:
                span.set_attribute("error", True)
                logger.warning(f"Product not found: {product_id}")
                raise HTTPException(status_code=404, detail=f"Product with id '{product_id}' not found")
            
            # Record product view metric
            catalog_metrics.record_product_view(product_id)
            
            logger.info(f"GET /api/products/{product_id} - Product found")
            return product
            
        except HTTPException:
            raise
            
        except SimulatedError as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Simulated error in get_product: {e}")
            raise HTTPException(status_code=503, detail=str(e))
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Error in get_product: {e}")
            raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/products/search", response_model=List[ProductResponse])
async def search_products(
    q: Optional[str] = Query(None, description="Search query for product name or description"),
    category: Optional[str] = Query(None, description="Filter by category (food, toys, accessories, beds)"),
    skip: int = Query(0, ge=0, description="Number of records to skip"),
    limit: int = Query(100, ge=1, le=500, description="Maximum number of records to return"),
    db: Session = Depends(get_db)
):
    """
    Search products by query and/or category.
    
    Args:
        q: Search query for name/description
        category: Filter by category
        skip: Number of records to skip (default: 0)
        limit: Maximum number of records to return (default: 100, max: 500)
        db: Database session
        
    Returns:
        List of matching products
    """
    with tracer.start_as_current_span("api.search_products") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/api/products/search")
        span.set_attribute("search.query", q or "")
        span.set_attribute("search.category", category or "")
        span.set_attribute("pagination.skip", skip)
        span.set_attribute("pagination.limit", limit)
        
        try:
            # Check for chaos engineering simulations
            await chaos_simulator.check_and_apply_chaos("catalog-service", feature_flag_client)
            
            # Validate category if provided
            if category:
                allowed_categories = ['food', 'toys', 'accessories', 'beds']
                if category.lower() not in allowed_categories:
                    span.set_attribute("error", True)
                    logger.warning(f"Invalid category: {category}")
                    raise HTTPException(
                        status_code=400, 
                        detail=f"Invalid category. Must be one of: {', '.join(allowed_categories)}"
                    )
            
            repo = ProductRepository(db)
            products = await repo.search(
                query=q,
                category=category,
                skip=skip,
                limit=limit
            )
            
            # Record search metric
            catalog_metrics.record_search(
                has_query=q is not None,
                has_category=category is not None
            )
            
            span.set_attribute("response.count", len(products))
            logger.info(f"GET /api/products/search - Returned {len(products)} products")
            
            return products
            
        except HTTPException:
            raise
            
        except SimulatedError as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Simulated error in search_products: {e}")
            raise HTTPException(status_code=503, detail=str(e))
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Error in search_products: {e}")
            raise HTTPException(status_code=500, detail="Internal server error")


@router.get("/chaos/metrics")
async def get_chaos_metrics():
    """
    Get system metrics and active chaos simulations.
    
    Returns:
        Dictionary containing service name, timestamp, and system metrics
    """
    with tracer.start_as_current_span("api.get_chaos_metrics") as span:
        span.set_attribute("http.method", "GET")
        span.set_attribute("http.route", "/chaos/metrics")
        
        try:
            metrics = chaos_simulator.get_system_metrics()
            response = {
                "service": "catalog-service",
                "timestamp": metrics.get("timestamp"),
                "system_metrics": metrics
            }
            
            logger.info("GET /chaos/metrics - Returned system metrics")
            return response
            
        except Exception as e:
            span.set_attribute("error", True)
            span.record_exception(e)
            logger.error(f"Error in get_chaos_metrics: {e}")
            raise HTTPException(status_code=500, detail="Internal server error")
