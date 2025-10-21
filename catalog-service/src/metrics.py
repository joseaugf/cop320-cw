"""Custom metrics for the catalog service."""

from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

from .config import settings


class CatalogMetrics:
    """Custom metrics for catalog service operations."""
    
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
        
        # Request counter
        self.request_counter = self.meter.create_counter(
            name="catalog.requests.total",
            description="Total number of requests to catalog service",
            unit="1"
        )
        
        # Error counter
        self.error_counter = self.meter.create_counter(
            name="catalog.errors.total",
            description="Total number of errors in catalog service",
            unit="1"
        )
        
        # Request duration histogram
        self.request_duration = self.meter.create_histogram(
            name="catalog.request.duration",
            description="Duration of catalog service requests",
            unit="ms"
        )
        
        # Product views counter
        self.product_views = self.meter.create_counter(
            name="catalog.product.views",
            description="Number of times products are viewed",
            unit="1"
        )
        
        # Search counter
        self.search_counter = self.meter.create_counter(
            name="catalog.search.total",
            description="Total number of product searches",
            unit="1"
        )
    
    def record_request(self, endpoint: str, method: str, status_code: int):
        """Record a request."""
        self.request_counter.add(
            1,
            {
                "endpoint": endpoint,
                "method": method,
                "status_code": str(status_code)
            }
        )
    
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
    
    def record_product_view(self, product_id: str):
        """Record a product view."""
        self.product_views.add(
            1,
            {"product_id": product_id}
        )
    
    def record_search(self, has_query: bool, has_category: bool):
        """Record a search operation."""
        self.search_counter.add(
            1,
            {
                "has_query": str(has_query),
                "has_category": str(has_category)
            }
        )


# Global metrics instance
catalog_metrics = CatalogMetrics()
