from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import time

from .config import settings
from .instrumentation import setup_instrumentation, instrument_app
from .database import engine, Base
from .http_client import http_client
from .logging_config import setup_logging
from .routes import router
from .metrics import checkout_metrics


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    print(f"Starting {settings.otel_service_name}...")
    
    # Create database tables
    Base.metadata.create_all(bind=engine)
    
    yield
    
    # Shutdown
    print(f"Shutting down {settings.otel_service_name}...")
    await http_client.close()


# Setup OpenTelemetry and logging before creating the app
setup_instrumentation()
setup_logging()

# Create FastAPI application
app = FastAPI(
    title="Checkout Service",
    description="Petshop checkout and order processing service with observability",
    version="1.0.0",
    lifespan=lifespan
)

# Instrument the FastAPI app
instrument_app(app)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Metrics middleware
@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to record metrics for all requests."""
    start_time = time.time()
    
    try:
        response = await call_next(request)
        
        # Calculate duration
        duration_ms = (time.time() - start_time) * 1000
        
        # Record metrics
        checkout_metrics.record_duration(
            endpoint=request.url.path,
            duration_ms=duration_ms
        )
        
        return response
        
    except Exception as e:
        # Record error
        checkout_metrics.record_error(
            endpoint=request.url.path,
            error_type=type(e).__name__
        )
        raise

# Include API routes
app.include_router(router)


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "service": settings.otel_service_name
    }


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "checkout-service",
        "version": "1.0.0"
    }
