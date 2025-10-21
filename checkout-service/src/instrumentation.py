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
    """Setup OpenTelemetry instrumentation."""
    # Create resource with service information
    resource = Resource.create({
        "service.name": settings.otel_service_name,
        "service.namespace": settings.otel_service_namespace,
    })
    
    # Create tracer provider
    tracer_provider = TracerProvider(resource=resource)
    
    # Create OTLP exporter
    otlp_exporter = OTLPSpanExporter(
        endpoint=settings.otel_exporter_otlp_endpoint,
        insecure=True
    )
    
    # Add span processor
    span_processor = BatchSpanProcessor(otlp_exporter)
    tracer_provider.add_span_processor(span_processor)
    
    # Set global tracer provider
    trace.set_tracer_provider(tracer_provider)
    
    # Instrument HTTPX for HTTP client calls
    HTTPXClientInstrumentor().instrument()
    
    print(f"OpenTelemetry instrumentation configured for {settings.otel_service_name}")


def instrument_app(app):
    """Instrument FastAPI application."""
    FastAPIInstrumentor.instrument_app(app)


def instrument_db(engine):
    """Instrument SQLAlchemy database engine."""
    SQLAlchemyInstrumentor().instrument(
        engine=engine,
        service=settings.otel_service_name
    )


def get_tracer():
    """Get tracer instance."""
    return trace.get_tracer(__name__)
