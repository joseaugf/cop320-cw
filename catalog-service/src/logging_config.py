"""Logging configuration with OpenTelemetry integration."""

import logging
import sys
from opentelemetry import trace
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.sdk.resources import Resource

from .config import settings


class TraceContextFilter(logging.Filter):
    """Filter to add trace context to log records."""
    
    def filter(self, record):
        """Add trace_id and span_id to log record."""
        span = trace.get_current_span()
        if span:
            span_context = span.get_span_context()
            if span_context.is_valid:
                record.trace_id = format(span_context.trace_id, '032x')
                record.span_id = format(span_context.span_id, '016x')
            else:
                record.trace_id = '0' * 32
                record.span_id = '0' * 16
        else:
            record.trace_id = '0' * 32
            record.span_id = '0' * 16
        
        record.service_name = settings.otel_service_name
        return True


def setup_logging():
    """Configure structured logging with OpenTelemetry."""
    
    # Create resource
    resource = Resource.create({
        "service.name": settings.otel_service_name,
        "service.namespace": settings.otel_service_namespace,
    })
    
    # Setup log exporter
    log_exporter = OTLPLogExporter(
        endpoint=settings.otel_exporter_otlp_endpoint,
        insecure=True
    )
    
    # Create logger provider
    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(
        BatchLogRecordProcessor(log_exporter)
    )
    
    # Create logging handler
    handler = LoggingHandler(
        level=logging.INFO,
        logger_provider=logger_provider
    )
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    
    # Add trace context filter
    trace_filter = TraceContextFilter()
    
    # Console handler with formatting
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter(
        '%(asctime)s - %(service_name)s - %(name)s - %(levelname)s - '
        '[trace_id=%(trace_id)s span_id=%(span_id)s] - %(message)s'
    )
    console_handler.setFormatter(console_formatter)
    console_handler.addFilter(trace_filter)
    
    # Add handlers
    root_logger.addHandler(console_handler)
    root_logger.addHandler(handler)
    
    # Reduce noise from some libraries
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    
    return root_logger
