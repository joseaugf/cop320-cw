"""
Shared OpenTelemetry instrumentation configuration for Python services
"""
import os
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.semconv.resource import ResourceAttributes


def setup_telemetry(service_name: str, service_version: str = "1.0.0"):
    """
    Setup OpenTelemetry instrumentation for a Python service
    
    Args:
        service_name: Name of the service
        service_version: Version of the service
    """
    # Get OTLP endpoint from environment or use default
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "adot-collector:4317")
    
    # Create resource with service information
    resource = Resource.create({
        ResourceAttributes.SERVICE_NAME: service_name,
        ResourceAttributes.SERVICE_VERSION: service_version,
        ResourceAttributes.SERVICE_NAMESPACE: "petshop-demo",
        ResourceAttributes.DEPLOYMENT_ENVIRONMENT: os.getenv("ENVIRONMENT", "demo"),
    })
    
    # Setup tracing
    trace_provider = TracerProvider(resource=resource)
    otlp_trace_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
    trace_provider.add_span_processor(BatchSpanProcessor(otlp_trace_exporter))
    trace.set_tracer_provider(trace_provider)
    
    # Setup metrics
    otlp_metric_exporter = OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
    metric_reader = PeriodicExportingMetricReader(otlp_metric_exporter, export_interval_millis=10000)
    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)
    
    return trace.get_tracer(__name__), metrics.get_meter(__name__)
