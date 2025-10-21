"""API routes for checkout service."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from opentelemetry import trace
from datetime import datetime
import logging

from .database import get_db
from .schemas import CheckoutRequest, OrderResponse, ErrorResponse
from .checkout_service import checkout_service, CheckoutError
from .metrics import checkout_metrics
from .chaos_simulator import chaos_simulator
from .feature_flag_client import feature_flag_client

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["checkout"])


def create_error_response(code: str, message: str, trace_id: str = None) -> dict:
    """Create standardized error response."""
    if not trace_id:
        span = trace.get_current_span()
        span_context = span.get_span_context()
        if span_context.is_valid:
            trace_id = format(span_context.trace_id, "032x")
    
    return {
        "error": {
            "code": code,
            "message": message,
            "trace_id": trace_id,
            "timestamp": datetime.utcnow().isoformat() + "Z"
        }
    }


@router.post(
    "/checkout",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid request"},
        500: {"model": ErrorResponse, "description": "Checkout failed"}
    }
)
async def process_checkout(
    checkout_data: CheckoutRequest,
    db: Session = Depends(get_db)
):
    """
    Process checkout and create order.
    
    - **session_id**: Session ID for the cart
    - **customer_email**: Customer email (optional)
    - **shipping_address**: Shipping address (optional)
    """
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span("api.checkout") as span:
        span.set_attribute("session_id", checkout_data.session_id)
        
        # Record checkout attempt
        checkout_metrics.record_checkout_attempt(checkout_data.session_id)
        
        try:
            # Check for chaos engineering simulations (network delay focus)
            await chaos_simulator.check_and_apply_chaos(
                "checkout-service",
                feature_flag_client
            )
            
            logger.info(
                "Processing checkout request",
                extra={"session_id": checkout_data.session_id}
            )
            
            order = await checkout_service.process_checkout(checkout_data, db)
            
            # Record successful checkout
            checkout_metrics.record_checkout_success(order.id, order.total)
            
            logger.info(
                "Checkout completed successfully",
                extra={"order_id": order.id, "session_id": checkout_data.session_id}
            )
            
            return order.to_dict()
            
        except CheckoutError as e:
            # Record checkout failure
            checkout_metrics.record_checkout_failure(checkout_data.session_id, "CheckoutError")
            
            logger.error(
                f"Checkout failed: {e}",
                extra={"session_id": checkout_data.session_id}
            )
            span.set_attribute("error", True)
            span.set_attribute("error.type", "CheckoutError")
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=create_error_response("CHECKOUT_FAILED", str(e))
            )
            
        except Exception as e:
            # Record checkout failure
            checkout_metrics.record_checkout_failure(checkout_data.session_id, type(e).__name__)
            
            logger.error(
                f"Unexpected error during checkout: {e}",
                extra={"session_id": checkout_data.session_id},
                exc_info=True
            )
            span.set_attribute("error", True)
            span.set_attribute("error.type", type(e).__name__)
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=create_error_response("INTERNAL_ERROR", "An unexpected error occurred")
            )


@router.get(
    "/orders/{order_id}",
    response_model=OrderResponse,
    responses={
        404: {"model": ErrorResponse, "description": "Order not found"}
    }
)
def get_order(
    order_id: str,
    db: Session = Depends(get_db)
):
    """
    Get order details by ID.
    
    - **order_id**: Order ID
    """
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span("api.get_order") as span:
        span.set_attribute("order.id", order_id)
        
        try:
            logger.info("Fetching order", extra={"order_id": order_id})
            
            order = checkout_service.get_order_by_id(order_id, db)
            
            if not order:
                logger.warning("Order not found", extra={"order_id": order_id})
                span.set_attribute("order.found", False)
                
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=create_error_response("ORDER_NOT_FOUND", f"Order with id {order_id} not found")
                )
            
            span.set_attribute("order.found", True)
            span.set_attribute("order.status", order.status)
            
            return order.to_dict()
            
        except HTTPException:
            raise
            
        except Exception as e:
            logger.error(
                f"Error fetching order: {e}",
                extra={"order_id": order_id},
                exc_info=True
            )
            span.set_attribute("error", True)
            span.set_attribute("error.type", type(e).__name__)
            
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=create_error_response("INTERNAL_ERROR", "An unexpected error occurred")
            )


@router.get("/chaos/metrics")
async def get_chaos_metrics():
    """
    Get system metrics and active chaos simulations.
    
    Returns current system metrics including CPU, memory, disk I/O,
    and list of active chaos simulations.
    """
    try:
        metrics = chaos_simulator.get_system_metrics()
        return {
            "service": "checkout-service",
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "system_metrics": metrics
        }
    except Exception as e:
        logger.error(f"Error getting chaos metrics: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=create_error_response("METRICS_ERROR", "Failed to retrieve chaos metrics")
        )
