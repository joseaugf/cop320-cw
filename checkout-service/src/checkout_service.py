"""Checkout service business logic."""

import logging
import asyncio
from typing import Dict, Any
from sqlalchemy.orm import Session
from opentelemetry import trace

from .models import Order, OrderItem
from .schemas import CheckoutRequest
from .http_client import http_client
from .failure_simulator import failure_simulator, SimulatedError

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class CheckoutError(Exception):
    """Exception raised for checkout errors."""
    pass


class CheckoutService:
    """Service for processing checkout operations."""
    
    async def process_checkout(self, checkout_data: CheckoutRequest, db: Session) -> Order:
        """
        Process checkout and create order.
        
        Args:
            checkout_data: Checkout request data
            db: Database session
            
        Returns:
            Created order
            
        Raises:
            CheckoutError: If checkout fails
        """
        with tracer.start_as_current_span("checkout.process") as span:
            span.set_attribute("session_id", checkout_data.session_id)
            
            try:
                # Step 1: Check for failure simulation
                await failure_simulator.check_and_apply_failures("checkout")
                
                # Step 2: Validate cart (use items from request if provided, otherwise fetch from cart service)
                if checkout_data.items:
                    cart_data = self._build_cart_from_items(checkout_data.items)
                else:
                    cart_data = await self._validate_cart(checkout_data.session_id)
                
                # Step 3: Create order
                order = await self._create_order(checkout_data, cart_data, db)
                
                # Step 4: Process payment (simulated)
                await self._process_payment(order)
                
                # Step 5: Update order status
                order.status = "confirmed"
                db.commit()
                db.refresh(order)
                
                # Step 6: Clear cart
                await self._clear_cart(checkout_data.session_id)
                
                logger.info(
                    "Checkout completed successfully",
                    extra={"order_id": order.id, "session_id": checkout_data.session_id}
                )
                
                span.set_attribute("order.id", order.id)
                span.set_attribute("order.total", order.total)
                span.set_attribute("order.status", order.status)
                
                return order
                
            except SimulatedError as e:
                logger.error(f"Simulated checkout failure: {e}")
                span.set_attribute("error", True)
                span.set_attribute("error.type", "SimulatedError")
                raise CheckoutError(str(e))
                
            except Exception as e:
                logger.error(f"Checkout failed: {e}", exc_info=True)
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                
                # Rollback transaction
                db.rollback()
                
                raise CheckoutError(f"Failed to process checkout: {str(e)}")
    
    def _build_cart_from_items(self, items: list) -> Dict[str, Any]:
        """
        Build cart data from provided items.
        
        Args:
            items: List of checkout items
            
        Returns:
            Cart data dictionary
            
        Raises:
            CheckoutError: If items are invalid
        """
        if not items:
            raise CheckoutError("Cart is empty")
        
        cart_items = []
        total = 0.0
        
        for item in items:
            cart_items.append({
                "productId": item.product_id,
                "name": item.product_name,
                "quantity": item.quantity,
                "price": item.price
            })
            total += item.price * item.quantity
        
        return {
            "items": cart_items,
            "total": round(total, 2)
        }
    
    async def _validate_cart(self, session_id: str) -> Dict[str, Any]:
        """
        Validate cart by fetching from Cart Service.
        
        Args:
            session_id: Session ID
            
        Returns:
            Cart data
            
        Raises:
            CheckoutError: If cart is invalid or empty
        """
        with tracer.start_as_current_span("checkout.validate_cart") as span:
            span.set_attribute("session_id", session_id)
            
            try:
                cart_data = await http_client.get_cart(session_id)
                
                if not cart_data or not cart_data.get("items"):
                    raise CheckoutError("Cart is empty")
                
                total = cart_data.get("total", 0)
                if total <= 0:
                    raise CheckoutError("Cart total must be greater than 0")
                
                span.set_attribute("cart.items_count", len(cart_data.get("items", [])))
                span.set_attribute("cart.total", total)
                
                logger.info(
                    "Cart validated successfully",
                    extra={"session_id": session_id, "items_count": len(cart_data.get("items", []))}
                )
                
                return cart_data
                
            except CheckoutError:
                raise
            except Exception as e:
                logger.error(f"Failed to validate cart: {e}")
                raise CheckoutError(f"Failed to validate cart: {str(e)}")
    
    async def _create_order(self, checkout_data: CheckoutRequest, cart_data: Dict[str, Any], db: Session) -> Order:
        """
        Create order in database.
        
        Args:
            checkout_data: Checkout request data
            cart_data: Cart data from Cart Service
            db: Database session
            
        Returns:
            Created order
        """
        with tracer.start_as_current_span("checkout.create_order") as span:
            try:
                # Create order
                order = Order(
                    session_id=checkout_data.session_id,
                    customer_email=checkout_data.customer_email,
                    shipping_address=checkout_data.shipping_address,
                    total=cart_data.get("total", 0),
                    status="pending"
                )
                
                db.add(order)
                db.flush()  # Get order ID
                
                # Create order items
                for item in cart_data.get("items", []):
                    order_item = OrderItem(
                        order_id=order.id,
                        product_id=item.get("productId"),
                        product_name=item.get("name"),
                        quantity=item.get("quantity"),
                        price=item.get("price")
                    )
                    db.add(order_item)
                
                db.commit()
                db.refresh(order)
                
                span.set_attribute("order.id", order.id)
                span.set_attribute("order.items_count", len(cart_data.get("items", [])))
                
                logger.info(
                    "Order created successfully",
                    extra={"order_id": order.id, "session_id": checkout_data.session_id}
                )
                
                return order
                
            except Exception as e:
                logger.error(f"Failed to create order: {e}")
                db.rollback()
                raise
    
    async def _process_payment(self, order: Order):
        """
        Simulate payment processing.
        
        Args:
            order: Order to process payment for
        """
        with tracer.start_as_current_span("checkout.process_payment") as span:
            span.set_attribute("order.id", order.id)
            span.set_attribute("order.total", order.total)
            
            # Simulate payment processing delay
            await asyncio.sleep(0.5)
            
            logger.info(
                "Payment processed successfully",
                extra={"order_id": order.id, "amount": order.total}
            )
            
            span.add_event("payment_processed", {"amount": order.total})
    
    async def _clear_cart(self, session_id: str):
        """
        Clear cart after successful checkout.
        
        Args:
            session_id: Session ID
        """
        with tracer.start_as_current_span("checkout.clear_cart") as span:
            span.set_attribute("session_id", session_id)
            
            try:
                await http_client.clear_cart(session_id)
                logger.info("Cart cleared successfully", extra={"session_id": session_id})
                
            except Exception as e:
                # Log error but don't fail checkout
                logger.warning(f"Failed to clear cart: {e}", extra={"session_id": session_id})
                span.set_attribute("error", True)
    
    def get_order_by_id(self, order_id: str, db: Session) -> Order:
        """
        Get order by ID.
        
        Args:
            order_id: Order ID
            db: Database session
            
        Returns:
            Order or None if not found
        """
        with tracer.start_as_current_span("checkout.get_order") as span:
            span.set_attribute("order.id", order_id)
            
            order = db.query(Order).filter(Order.id == order_id).first()
            
            if order:
                span.set_attribute("order.status", order.status)
                span.set_attribute("order.total", order.total)
            
            return order


# Global instance
checkout_service = CheckoutService()
