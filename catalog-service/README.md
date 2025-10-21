# Catalog Service

Product catalog service for the Petshop Observability Demo. Built with Python and FastAPI.

## Features

- Product catalog management
- Search and filtering
- OpenTelemetry instrumentation
- Failure simulation via feature flags
- PostgreSQL database

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

The service will be available at `http://localhost:8001`

## API Endpoints

- `GET /health` - Health check
- `GET /api/products` - List all products
- `GET /api/products/{id}` - Get product by ID
- `GET /api/products/search` - Search products

## Development

The service uses:
- FastAPI for the web framework
- SQLAlchemy for database ORM
- OpenTelemetry for observability
- PostgreSQL for data storage
