"""Custom metrics for the checkout service."""

from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

from .config import settings


class CheckoutMetrics:
    """Custom metrics for checkout service operations."""
    
    def __init__(self):
        # Create resource
        resource = Resource.create({
            "service.name": settings.otel_service_name,
            "service.namespace": settings.otel_service_namespace,
        })
        
        # Setup metric exporter
        metric_exporter = OTLPMetricExporter(
            endpoint=settings.otel_exporter_otlp_endpoint,
            insecure=True
        )
        
        # Create metric reader
        metric_reader = PeriodicExportingMetricReader(
            metric_exporter,
            export_interval_millis=10000  # Export every 10 seconds
        )
        
        # Setup meter provider
        provider = MeterProvider(
            resource=resource,
            metric_readers=[metric_reader]
        )
        metrics.set_meter_provider(provider)
        
        # Get meter
        self.meter = metrics.get_meter(__name__)
        
        # Create metrics
        self._setup_metrics()
    
    def _setup_metrics(self):
        """Setup custom metrics."""
        
        # Checkout attempts counter
        self.checkout_attempts = self.meter.create_counter(
            name="checkout.attempts.total",
            description="Total number of checkout attempts",
            unit="1"
        )
        
        # Checkout success counter
        self.checkout_success = self.meter.create_counter(
            name="checkout.success.total",
            description="Total number of successful checkouts",
            unit="1"
        )
        
        # Checkout failures counter
        self.checkout_failures = self.meter.create_counter(
            name="checkout.failures.total",
            description="Total number of failed checkouts",
            unit="1"
        )
        
        # Order value histogram
        self.order_value = self.meter.create_histogram(
            name="checkout.order.value",
            description="Value of orders processed",
            unit="USD"
        )
        
        # Request duration histogram
        self.request_duration = self.meter.create_histogram(
            name="checkout.request.duration",
            description="Duration of checkout service requests",
            unit="ms"
        )
        
        # Error counter
        self.error_counter = self.meter.create_counter(
            name="checkout.errors.total",
            description="Total number of errors in checkout service",
            unit="1"
        )
    
    def record_checkout_attempt(self, session_id: str):
        """Record a checkout attempt."""
        self.checkout_attempts.add(
            1,
            {"session_id": session_id}
        )
    
    def record_checkout_success(self, order_id: str, order_value: float):
        """Record a successful checkout."""
        self.checkout_success.add(1, {"order_id": order_id})
        self.order_value.record(order_value, {"order_id": order_id})
    
    def record_checkout_failure(self, session_id: str, error_type: str):
        """Record a failed checkout."""
        self.checkout_failures.add(
            1,
            {
                "session_id": session_id,
                "error_type": error_type
            }
        )
    
    def record_request(self, endpoint: str, method: str, status_code: int):
        """Record a request."""
        pass  # Will be handled by middleware
    
    def record_error(self, endpoint: str, error_type: str):
        """Record an error."""
        self.error_counter.add(
            1,
            {
                "endpoint": endpoint,
                "error_type": error_type
            }
        )
    
    def record_duration(self, endpoint: str, duration_ms: float):
        """Record request duration."""
        self.request_duration.record(
            duration_ms,
            {"endpoint": endpoint}
        )


# Global metrics instance
checkout_metrics = CheckoutMetrics()
