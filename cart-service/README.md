# Cart Service

Shopping cart service for the Petshop Observability Demo.

## Overview

The Cart Service manages shopping cart operations using Redis for storage. It provides REST API endpoints for adding, updating, and removing items from user carts.

## Technology Stack

- Node.js 20+
- Express.js
- TypeScript
- Redis (for cart storage)
- OpenTelemetry (for observability)

## Features

- Session-based cart management
- Redis storage with 24-hour TTL
- Automatic cart total calculation
- OpenTelemetry instrumentation for traces and metrics
- Failure simulation via feature flags
- Health check endpoint

## API Endpoints

- `GET /health` - Health check endpoint
- `GET /api/cart` - Retrieve cart by session
- `POST /api/cart/items` - Add item to cart
- `PUT /api/cart/items/:id` - Update item quantity
- `DELETE /api/cart/items/:id` - Remove item from cart
- `DELETE /api/cart` - Clear entire cart

## Environment Variables

```bash
PORT=3001
REDIS_URL=redis://localhost:6379
FEATURE_FLAG_SERVICE_URL=http://localhost:3003
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

## Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Build
npm run build

# Run production
npm start
```

## Observability

The service is instrumented with OpenTelemetry and sends:
- **Traces**: Distributed traces for all HTTP requests and Redis operations
- **Metrics**: Custom metrics for cart operations, cart value, and item counts
- **Logs**: Structured logs with trace context

All telemetry data is sent to the ADOT Collector configured via `OTEL_EXPORTER_OTLP_ENDPOINT`.
