from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

from .config import settings


def setup_instrumentation():
    """Configure OpenTelemetry instrumentation for the catalog service."""
    
    # Create resource with service information
    resource = Resource.create({
        "service.name": settings.otel_service_name,
        "service.namespace": settings.otel_service_namespace,
    })
    
    # Setup tracer provider
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)
    
    # Configure OTLP exporter
    otlp_exporter = OTLPSpanExporter(
        endpoint=settings.otel_exporter_otlp_endpoint,
        insecure=True
    )
    
    # Add span processor
    span_processor = BatchSpanProcessor(otlp_exporter)
    provider.add_span_processor(span_processor)
    
    # Instrument libraries
    HTTPXClientInstrumentor().instrument()
    
    return provider


def instrument_app(app):
    """Instrument FastAPI application."""
    FastAPIInstrumentor.instrument_app(app)


def instrument_db(engine):
    """Instrument SQLAlchemy engine."""
    SQLAlchemyInstrumentor().instrument(engine=engine)
