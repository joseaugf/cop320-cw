import httpx
from opentelemetry import trace
from opentelemetry.trace.propagation.tracecontext import TraceContextTextMapPropagator

from .config import settings


class HTTPClient:
    """HTTP client for service-to-service communication with trace propagation."""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)
        self.propagator = TraceContextTextMapPropagator()
    
    def _inject_trace_context(self, headers: dict) -> dict:
        """Inject trace context into HTTP headers."""
        carrier = headers.copy()
        self.propagator.inject(carrier)
        return carrier
    
    async def get_cart(self, session_id: str) -> dict:
        """Get cart from Cart Service."""
        tracer = trace.get_tracer(__name__)
        
        with tracer.start_as_current_span("cart_service.get_cart") as span:
            span.set_attribute("session_id", session_id)
            
            headers = self._inject_trace_context({})
            url = f"{settings.cart_service_url}/api/cart"
            params = {"sessionId": session_id}
            
            try:
                response = await self.client.get(url, params=params, headers=headers)
                response.raise_for_status()
                
                cart_data = response.json()
                span.set_attribute("cart.items_count", len(cart_data.get("items", [])))
                span.set_attribute("cart.total", cart_data.get("total", 0))
                
                return cart_data
                
            except httpx.HTTPError as e:
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                raise
    
    async def clear_cart(self, session_id: str) -> None:
        """Clear cart in Cart Service."""
        tracer = trace.get_tracer(__name__)
        
        with tracer.start_as_current_span("cart_service.clear_cart") as span:
            span.set_attribute("session_id", session_id)
            
            headers = self._inject_trace_context({})
            url = f"{settings.cart_service_url}/api/cart"
            params = {"sessionId": session_id}
            
            try:
                response = await self.client.delete(url, params=params, headers=headers)
                response.raise_for_status()
                
            except httpx.HTTPError as e:
                span.set_attribute("error", True)
                span.set_attribute("error.type", type(e).__name__)
                raise
    
    async def close(self):
        """Close the HTTP client."""
        await self.client.aclose()


# Global HTTP client instance
http_client = HTTPClient()
