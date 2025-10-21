import logging
import json
from datetime import datetime
from opentelemetry import trace


class StructuredFormatter(logging.Formatter):
    """Custom formatter for structured JSON logging with trace context."""
    
    def format(self, record):
        # Get current span context
        span = trace.get_current_span()
        span_context = span.get_span_context()
        
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "service": "checkout-service"
        }
        
        # Add trace context if available
        if span_context.is_valid:
            log_data["trace_id"] = format(span_context.trace_id, "032x")
            log_data["span_id"] = format(span_context.span_id, "016x")
        
        # Add extra fields
        if hasattr(record, "order_id"):
            log_data["order_id"] = record.order_id
        
        if hasattr(record, "session_id"):
            log_data["session_id"] = record.session_id
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        
        return json.dumps(log_data)


def setup_logging():
    """Setup structured logging configuration."""
    # Get root logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Remove existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    # Create console handler with structured formatter
    handler = logging.StreamHandler()
    handler.setFormatter(StructuredFormatter())
    logger.addHandler(handler)
    
    # Set level for third-party loggers
    logging.getLogger("uvicorn").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    
    print("Structured logging configured")
