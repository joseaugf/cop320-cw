"""Failure simulation logic for demonstrating observability."""

import asyncio
import random
import logging
from opentelemetry import trace

from .feature_flag_client import feature_flag_client

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class SimulatedError(Exception):
    """Exception raised for simulated errors."""
    pass


class FailureSimulator:
    """Handles failure simulation based on feature flags."""
    
    async def check_and_apply_failures(self, operation: str = "checkout_operation"):
        """
        Check feature flags and apply failure simulations.
        
        Args:
            operation: Name of the operation being performed
            
        Raises:
            SimulatedError: If error simulation is triggered
        """
        with tracer.start_as_current_span("failure_simulation.check") as span:
            span.set_attribute("operation", operation)
            
            # Check for checkout failure simulation
            await self._simulate_checkout_failure(span)
    
    async def _simulate_checkout_failure(self, span):
        """Simulate checkout failures if flag is enabled."""
        flag_name = "checkout_failure"
        
        if await feature_flag_client.is_flag_enabled(flag_name):
            config = await feature_flag_client.get_flag_config(flag_name)
            failure_rate = config.get("failureRate", 50)  # Default 50%
            
            # Generate random number to determine if failure should occur
            if random.randint(0, 100) < failure_rate:
                logger.error(f"Simulating checkout failure (rate: {failure_rate}%)")
                span.set_attribute("simulated.failure", True)
                span.set_attribute("simulated.failure_rate", failure_rate)
                span.add_event("checkout_failure_simulation", {"failure_rate": failure_rate})
                
                raise SimulatedError(f"Simulated checkout failure for observability demo (failure rate: {failure_rate}%)")


# Global instance
failure_simulator = FailureSimulator()
