# Checkout Service

Python/FastAPI service for processing checkout and managing orders in the Petshop Observability Demo.

## Features

- Order processing with transaction handling
- Cart validation via Cart Service
- Simulated payment processing
- Failure simulation via feature flags
- Full OpenTelemetry instrumentation (traces, metrics, logs)

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. Run the service:
```bash
python -m src.main
```

The service will be available at `http://localhost:8003`

## API Endpoints

- `POST /api/checkout` - Process checkout
- `GET /api/orders/:id` - Get order details
- `GET /health` - Health check

## Environment Variables

- `DATABASE_URL` - PostgreSQL connection string
- `CART_SERVICE_URL` - Cart service URL
- `FEATURE_FLAG_SERVICE_URL` - Feature flag service URL
- `OTEL_EXPORTER_OTLP_ENDPOINT` - ADOT Collector endpoint
- `OTEL_SERVICE_NAME` - Service name for telemetry
- `PORT` - Service port (default: 8003)
