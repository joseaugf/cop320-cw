"""Failure simulation logic for demonstrating observability."""

import asyncio
import random
import logging
from typing import Optional
from opentelemetry import trace

from .feature_flag_client import feature_flag_client

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class SimulatedError(Exception):
    """Exception raised for simulated errors."""
    pass


class FailureSimulator:
    """Handles failure simulation based on feature flags."""
    
    async def check_and_apply_failures(self, operation: str = "catalog_operation"):
        """
        Check feature flags and apply failure simulations.
        
        Args:
            operation: Name of the operation being performed
            
        Raises:
            SimulatedError: If error simulation is triggered
        """
        with tracer.start_as_current_span("failure_simulation.check") as span:
            span.set_attribute("operation", operation)
            
            # Check for high latency simulation
            await self._simulate_high_latency(span)
            
            # Check for error rate simulation
            await self._simulate_error_rate(span)
            
            # Check for slow query simulation
            await self._simulate_slow_queries(span)
    
    async def _simulate_high_latency(self, span):
        """Simulate high latency if flag is enabled."""
        flag_name = "catalog_high_latency"
        
        if await feature_flag_client.is_flag_enabled(flag_name):
            config = await feature_flag_client.get_flag_config(flag_name)
            latency_ms = config.get("latencyMs", 1000)
            
            logger.warning(f"Simulating high latency: {latency_ms}ms")
            span.set_attribute("simulated.latency_ms", latency_ms)
            span.add_event("high_latency_simulation", {"latency_ms": latency_ms})
            
            await asyncio.sleep(latency_ms / 1000.0)
    
    async def _simulate_error_rate(self, span):
        """Simulate errors based on configured error rate."""
        flag_name = "catalog_error_rate"
        
        if await feature_flag_client.is_flag_enabled(flag_name):
            config = await feature_flag_client.get_flag_config(flag_name)
            error_rate = config.get("errorRate", 30)  # Default 30%
            
            # Generate random number to determine if error should occur
            if random.randint(0, 100) < error_rate:
                logger.error(f"Simulating error (rate: {error_rate}%)")
                span.set_attribute("simulated.error", True)
                span.set_attribute("simulated.error_rate", error_rate)
                span.add_event("error_simulation", {"error_rate": error_rate})
                
                raise SimulatedError(f"Simulated error for observability demo (error rate: {error_rate}%)")
    
    async def _simulate_slow_queries(self, span):
        """Simulate slow database queries."""
        flag_name = "database_slow_queries"
        
        if await feature_flag_client.is_flag_enabled(flag_name):
            config = await feature_flag_client.get_flag_config(flag_name)
            delay_ms = config.get("delayMs", 500)
            
            logger.warning(f"Simulating slow query: {delay_ms}ms")
            span.set_attribute("simulated.slow_query_ms", delay_ms)
            span.add_event("slow_query_simulation", {"delay_ms": delay_ms})
            
            await asyncio.sleep(delay_ms / 1000.0)


# Global instance
failure_simulator = FailureSimulator()
