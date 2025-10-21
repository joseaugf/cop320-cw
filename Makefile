.PHONY: help build up down logs clean restart ps health test

# Default target
help:
	@echo "Petshop Observability Demo - Docker Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       - Build all Docker images"
	@echo "  up          - Start all services"
	@echo "  down        - Stop all services"
	@echo "  logs        - View logs from all services"
	@echo "  clean       - Stop services and remove volumes"
	@echo "  restart     - Restart all services"
	@echo "  ps          - Show running services"
	@echo "  health      - Check health of all services"
	@echo "  test        - Run basic connectivity tests"
	@echo ""
	@echo "Development:"
	@echo "  dev         - Start services in development mode with hot-reload"
	@echo "  dev-down    - Stop development services"
	@echo ""
	@echo "Individual Services:"
	@echo "  logs-catalog   - View catalog service logs"
	@echo "  logs-cart      - View cart service logs"
	@echo "  logs-checkout  - View checkout service logs"
	@echo "  logs-flags     - View feature flag service logs"
	@echo "  logs-frontend  - View frontend logs"
	@echo "  logs-adot      - View ADOT collector logs"

# Build all images
build:
	docker-compose build

# Start all services
up:
	docker-compose up -d
	@echo "Services starting..."
	@echo "Frontend: http://localhost:3000"
	@echo "Admin Panel: http://localhost:3000/admin"
	@echo "Catalog API: http://localhost:8001"
	@echo "Cart API: http://localhost:8002"
	@echo "Checkout API: http://localhost:8003"
	@echo "Feature Flags API: http://localhost:8004"

# Stop all services
down:
	docker-compose down

# View logs
logs:
	docker-compose logs -f

# Clean everything
clean:
	docker-compose down -v
	docker system prune -f

# Restart all services
restart:
	docker-compose restart

# Show running services
ps:
	docker-compose ps

# Check health of services
health:
	@echo "Checking service health..."
	@curl -s http://localhost:8001/health && echo "✓ Catalog Service" || echo "✗ Catalog Service"
	@curl -s http://localhost:8002/health && echo "✓ Cart Service" || echo "✗ Cart Service"
	@curl -s http://localhost:8003/health && echo "✓ Checkout Service" || echo "✗ Checkout Service"
	@curl -s http://localhost:8004/health && echo "✓ Feature Flag Service" || echo "✗ Feature Flag Service"
	@curl -s http://localhost:3000/health && echo "✓ Frontend" || echo "✗ Frontend"
	@curl -s http://localhost:13133/ && echo "✓ ADOT Collector" || echo "✗ ADOT Collector"

# Run basic tests
test:
	@echo "Running connectivity tests..."
	@curl -s http://localhost:8001/api/products | grep -q "id" && echo "✓ Catalog API responding" || echo "✗ Catalog API failed"
	@curl -s http://localhost:8004/api/flags | grep -q "name" && echo "✓ Feature Flags API responding" || echo "✗ Feature Flags API failed"

# Development mode
dev:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

dev-down:
	docker-compose -f docker-compose.yml -f docker-compose.dev.yml down

# Individual service logs
logs-catalog:
	docker-compose logs -f catalog-service

logs-cart:
	docker-compose logs -f cart-service

logs-checkout:
	docker-compose logs -f checkout-service

logs-flags:
	docker-compose logs -f feature-flag-service

logs-frontend:
	docker-compose logs -f frontend

logs-adot:
	docker-compose logs -f adot-collector

# Database operations
db-shell:
	docker-compose exec postgres psql -U petshop -d petshop

redis-shell:
	docker-compose exec redis redis-cli

# Rebuild specific service
rebuild-catalog:
	docker-compose build --no-cache catalog-service
	docker-compose up -d catalog-service

rebuild-cart:
	docker-compose build --no-cache cart-service
	docker-compose up -d cart-service

rebuild-checkout:
	docker-compose build --no-cache checkout-service
	docker-compose up -d checkout-service

rebuild-flags:
	docker-compose build --no-cache feature-flag-service
	docker-compose up -d feature-flag-service

rebuild-frontend:
	docker-compose build --no-cache frontend
	docker-compose up -d frontend
