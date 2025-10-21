"""Client for interacting with the Feature Flag Service."""

import httpx
import logging
from typing import Dict, Any, Optional
from opentelemetry import trace

from .config import settings

logger = logging.getLogger(__name__)
tracer = trace.get_tracer(__name__)


class FeatureFlagClient:
    """Client to fetch feature flags from the Feature Flag Service."""
    
    def __init__(self):
        self.base_url = settings.feature_flag_service_url
        self.timeout = 2.0  # 2 second timeout
    
    async def get_flag(self, flag_name: str) -> Optional[Dict[str, Any]]:
        """
        Get a specific feature flag.
        
        Args:
            flag_name: Name of the flag to retrieve
            
        Returns:
            Flag configuration or None if not found or service unavailable
        """
        with tracer.start_as_current_span("feature_flag.get_flag") as span:
            span.set_attribute("flag.name", flag_name)
            
            try:
                async with httpx.AsyncClient(timeout=self.timeout) as client:
                    response = await client.get(
                        f"{self.base_url}/api/flags/{flag_name}",
                        headers={"Content-Type": "application/json"}
                    )
                    
                    if response.status_code == 200:
                        flag_data = response.json()
                        span.set_attribute("flag.enabled", flag_data.get("enabled", False))
                        return flag_data
                    elif response.status_code == 404:
                        logger.warning(f"Flag '{flag_name}' not found")
                        return None
                    else:
                        logger.error(f"Error fetching flag: {response.status_code}")
                        return None
                        
            except httpx.TimeoutException:
                logger.warning(f"Timeout fetching flag '{flag_name}'")
                span.set_attribute("error", True)
                return None
            except Exception as e:
                logger.error(f"Error fetching flag '{flag_name}': {e}")
                span.set_attribute("error", True)
                return None
    
    async def is_flag_enabled(self, flag_name: str) -> bool:
        """
        Check if a feature flag is enabled.
        
        Args:
            flag_name: Name of the flag to check
            
        Returns:
            True if flag is enabled, False otherwise
        """
        flag = await self.get_flag(flag_name)
        return flag.get("enabled", False) if flag else False
    
    async def get_flag_config(self, flag_name: str) -> Dict[str, Any]:
        """
        Get the configuration for a feature flag.
        
        Args:
            flag_name: Name of the flag
            
        Returns:
            Flag configuration dictionary
        """
        flag = await self.get_flag(flag_name)
        return flag.get("config", {}) if flag else {}


# Global instance
feature_flag_client = FeatureFlagClient()
