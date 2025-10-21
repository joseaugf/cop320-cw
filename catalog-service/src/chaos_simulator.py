"""Chaos Engineering Simulator for safe infrastructure failure simulation."""

import asyncio
import logging
import os
import random
import threading
import time
from datetime import datetime
from typing import Dict, Any, Optional

try:
    import psutil
except ImportError:
    psutil = None

from .feature_flag_client import FeatureFlagClient

logger = logging.getLogger(__name__)


class ChaosSimulator:
    """Simulates infrastructure failures safely for chaos engineering demos."""
    
    def __init__(self):
        """Initialize the chaos simulator with state tracking."""
        self.active_simulations: Dict[str, bool] = {}
        self.disk_stress_thread: Optional[threading.Thread] = None
        self.crash_scheduler_thread: Optional[threading.Thread] = None
        self.stop_disk_stress = threading.Event()
        self.stop_crash_scheduler = threading.Event()
        
        # Track temp files for cleanup
        self.temp_files: list = []
        
        logger.info("ChaosSimulator initialized")
    
    async def check_and_apply_chaos(
        self, 
        service_name: str, 
        flag_client: FeatureFlagClient
    ) -> None:
        """
        Check for active chaos flags and apply corresponding simulations.
        
        Args:
            service_name: Name of the service (for logging)
            flag_client: Feature flag client to query flags
        """
        try:
            # Check disk stress flag
            disk_stress_flag = await flag_client.get_flag("infrastructure_disk_stress")
            if disk_stress_flag and disk_stress_flag.get("enabled"):
                await self._simulate_disk_stress(disk_stress_flag.get("config", {}))
            
            # Check pod crash flag
            pod_crash_flag = await flag_client.get_flag("infrastructure_pod_crash")
            if pod_crash_flag and pod_crash_flag.get("enabled"):
                await self._simulate_pod_crash(
                    pod_crash_flag.get("config", {}), 
                    service_name
                )
            
            # Check DB connection failure flag
            db_fail_flag = await flag_client.get_flag("infrastructure_db_connection_fail")
            if db_fail_flag and db_fail_flag.get("enabled"):
                await self._simulate_db_connection_fail(db_fail_flag.get("config", {}))
            
            # Check network delay flag
            network_delay_flag = await flag_client.get_flag("infrastructure_network_delay")
            if network_delay_flag and network_delay_flag.get("enabled"):
                await self._simulate_network_delay(network_delay_flag.get("config", {}))
                
        except Exception as e:
            # Don't let chaos simulator errors crash the service
            logger.error(f"Error in chaos simulation: {e}")
    
    async def _simulate_network_delay(self, config: Dict[str, Any]) -> None:
        """
        Simulate network latency between services.
        
        Args:
            config: Configuration with delayMs (base delay) and jitterMs (random variation)
        """
        delay_ms = config.get("delayMs", 2000)
        jitter_ms = config.get("jitterMs", 500)
        
        # Calculate actual delay with random jitter
        jitter = random.randint(-jitter_ms, jitter_ms)
        actual_delay_ms = max(0, delay_ms + jitter)
        
        logger.info(f"🔥 CHAOS: Simulating network delay ({actual_delay_ms}ms)")
        
        # Apply the delay
        await asyncio.sleep(actual_delay_ms / 1000.0)
    
    async def _simulate_db_connection_fail(self, config: Dict[str, Any]) -> None:
        """
        Simulate database connection failures.
        
        Args:
            config: Configuration with failureRate (0-100) and timeoutMs
            
        Raises:
            Exception: When simulating a connection failure
        """
        failure_rate = config.get("failureRate", 50)
        timeout_ms = config.get("timeoutMs", 1000)
        
        # Check if we should fail based on failure rate
        if random.randint(1, 100) <= failure_rate:
            logger.warning(
                f"🔥 CHAOS: Simulating database connection failure "
                f"(rate={failure_rate}%, timeout={timeout_ms}ms)"
            )
            
            # Simulate timeout delay
            await asyncio.sleep(timeout_ms / 1000.0)
            
            # Raise connection exception
            raise Exception("CHAOS: Simulated database connection failure")
    
    async def _simulate_pod_crash(
        self, 
        config: Dict[str, Any], 
        service_name: str
    ) -> None:
        """
        Simulate pod crashes by scheduling periodic exits.
        
        Args:
            config: Configuration with crashIntervalMinutes and crashProbability (0-100)
            service_name: Name of the service for logging
        """
        # Check if already running
        if self.active_simulations.get("pod_crash"):
            return
        
        interval_minutes = config.get("crashIntervalMinutes", 5)
        crash_probability = config.get("crashProbability", 30)
        
        logger.info(
            f"🔥 CHAOS: Starting pod crash scheduler "
            f"(interval={interval_minutes}min, probability={crash_probability}%)"
        )
        self.active_simulations["pod_crash"] = True
        
        # Reset stop event
        self.stop_crash_scheduler.clear()
        
        # Start crash scheduler in background thread
        def crash_scheduler_worker():
            try:
                interval_seconds = interval_minutes * 60
                
                while not self.stop_crash_scheduler.is_set():
                    # Wait for the interval
                    if self.stop_crash_scheduler.wait(timeout=interval_seconds):
                        break  # Stop event was set
                    
                    # Check if we should crash based on probability
                    if random.randint(1, 100) <= crash_probability:
                        logger.error(
                            f"🔥 CHAOS: Simulating pod crash for {service_name} "
                            f"(probability={crash_probability}%)"
                        )
                        # Force exit the process
                        os._exit(1)
                
            finally:
                self.active_simulations["pod_crash"] = False
                logger.info("🔥 CHAOS: Pod crash scheduler stopped")
        
        # Start thread if not already running
        if not self.crash_scheduler_thread or not self.crash_scheduler_thread.is_alive():
            self.crash_scheduler_thread = threading.Thread(
                target=crash_scheduler_worker, 
                daemon=True
            )
            self.crash_scheduler_thread.start()
    
    async def _simulate_disk_stress(self, config: Dict[str, Any]) -> None:
        """
        Simulate high disk I/O by creating intensive read/write operations.
        
        Args:
            config: Configuration with intensityLevel (1-10) and durationSeconds
        """
        # Check if already running
        if self.active_simulations.get("disk_stress"):
            return
        
        intensity = config.get("intensityLevel", 5)
        duration = config.get("durationSeconds", 30)
        
        logger.info(f"🔥 CHAOS: Starting disk I/O stress simulation (intensity={intensity}, duration={duration}s)")
        self.active_simulations["disk_stress"] = True
        
        # Reset stop event
        self.stop_disk_stress.clear()
        
        # Start disk stress in background thread
        def disk_stress_worker():
            try:
                start_time = time.time()
                file_size_mb = intensity  # 1-10 MB per file
                num_files = intensity  # 1-10 files
                
                # Create temp files
                for i in range(num_files):
                    if self.stop_disk_stress.is_set():
                        break
                    
                    temp_file = f"/tmp/chaos_disk_stress_{os.getpid()}_{i}.tmp"
                    self.temp_files.append(temp_file)
                    
                    try:
                        # Write operation
                        with open(temp_file, 'wb') as f:
                            data = os.urandom(file_size_mb * 1024 * 1024)
                            f.write(data)
                            f.flush()
                            os.fsync(f.fileno())
                        
                        # Read operation
                        with open(temp_file, 'rb') as f:
                            _ = f.read()
                    except Exception as e:
                        logger.warning(f"Error during disk I/O: {e}")
                
                # Keep doing I/O operations until duration expires
                while time.time() - start_time < duration:
                    if self.stop_disk_stress.is_set():
                        break
                    
                    # Perform read/write cycles on existing files
                    for temp_file in self.temp_files:
                        if self.stop_disk_stress.is_set():
                            break
                        
                        try:
                            if os.path.exists(temp_file):
                                # Read
                                with open(temp_file, 'rb') as f:
                                    _ = f.read()
                                
                                # Write
                                with open(temp_file, 'ab') as f:
                                    f.write(os.urandom(1024))
                                    f.flush()
                        except Exception as e:
                            logger.warning(f"Error during disk I/O cycle: {e}")
                    
                    time.sleep(0.1)  # Small delay between cycles
                
            finally:
                # Cleanup temp files
                for temp_file in self.temp_files:
                    try:
                        if os.path.exists(temp_file):
                            os.remove(temp_file)
                    except Exception as e:
                        logger.warning(f"Error removing temp file {temp_file}: {e}")
                
                self.temp_files.clear()
                self.active_simulations["disk_stress"] = False
                logger.info("🔥 CHAOS: Disk I/O stress simulation completed")
        
        # Start thread if not already running
        if not self.disk_stress_thread or not self.disk_stress_thread.is_alive():
            self.disk_stress_thread = threading.Thread(target=disk_stress_worker, daemon=True)
            self.disk_stress_thread.start()
    
    def get_system_metrics(self) -> Dict[str, Any]:
        """
        Get current system metrics for monitoring chaos effects.
        
        Returns:
            Dictionary containing system metrics and active simulations
        """
        metrics = {
            "timestamp": datetime.utcnow().isoformat(),
            "active_simulations": [
                name for name, active in self.active_simulations.items() if active
            ]
        }
        
        # Add system metrics if psutil is available
        if psutil:
            try:
                process = psutil.Process()
                metrics["cpu_usage_percent"] = process.cpu_percent(interval=0.1)
                metrics["memory_usage_mb"] = process.memory_info().rss / 1024 / 1024
                
                # Disk I/O metrics
                io_counters = process.io_counters()
                metrics["disk_io_read_bytes"] = io_counters.read_bytes
                metrics["disk_io_write_bytes"] = io_counters.write_bytes
            except Exception as e:
                logger.warning(f"Error collecting system metrics: {e}")
        else:
            logger.warning("psutil not available - system metrics disabled")
        
        return metrics


# Global instance
chaos_simulator = ChaosSimulator()
