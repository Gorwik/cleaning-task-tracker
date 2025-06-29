# Cleaning Tracker Test Makefile

.PHONY: help test test-build test-up test-down test-logs test-clean test-unit test-integration test-api test-watch test-coverage test-report

# Default target
help:
	@echo "Available targets:"
	@echo "  test-build     Build test environment"
	@echo "  test-up        Start test environment"
	@echo "  test-down      Stop test environment"
	@echo "  test           Run all tests"
	@echo "  test-unit      Run unit tests only"
	@echo "  test-api       Run API tests only"
	@echo "  test-integration  Run integration tests only"
	@echo "  test-watch     Run tests in watch mode"
	@echo "  test-coverage  Run tests with coverage report"
	@echo "  test-report    Open test report in browser"
	@echo "  test-logs      Show test logs"
	@echo "  test-clean     Clean test environment and volumes"
	@echo "  test-shell     Open shell in test container"

# Build test environment
test-build:
	docker-compose -f docker-compose.test.yml build --no-cache

# Start test services
test-up:
	docker-compose -f docker-compose.test.yml up -d postgres-test postgrest-test
	@echo "Waiting for services to be ready..."
	@sleep 10

# Stop test services
test-down:
	docker-compose -f docker-compose.test.yml down

# Run all tests
test: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner
	@$(MAKE) test-down

# Run unit tests only
test-unit: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner python -m pytest tests/ -m "unit" -v
	@$(MAKE) test-down

# Run API tests only
test-api: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner python -m pytest tests/ -m "api" -v
	@$(MAKE) test-down

# Run integration tests only
test-integration: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner python -m pytest tests/ -m "integration" -v
	@$(MAKE) test-down

# Run specific test file
test-file: test-up
	@if [ -z "$(FILE)" ]; then echo "Usage: make test-file FILE=test_file.py"; exit 1; fi
	docker-compose -f docker-compose.test.yml run --rm test-runner python -m pytest tests/$(FILE) -v
	@$(MAKE) test-down

# Run tests in watch mode (requires pytest-watch)
test-watch: test-up
	docker-compose -f docker-compose.test.yml run --rm -v $(PWD):/app test-runner python -m pytest tests/ -f --tb=short
	@$(MAKE) test-down

# Run tests with coverage
test-coverage: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner python -m pytest tests/ --cov=. --cov-report=html --cov-report=term-missing
	@$(MAKE) test-down

# Show test logs
test-logs:
	docker-compose -f docker-compose.test.yml logs test-runner

# Clean test environment
test-clean:
	docker-compose -f docker-compose.test.yml down -v --remove-orphans
	docker volume prune -f
	@echo "Test environment cleaned"

# Open shell in test container
test-shell: test-up
	docker-compose -f docker-compose.test.yml run --rm test-runner bash

# Open test report in browser (requires xdg-open or equivalent)
test-report:
	@if [ -f "reports/report.html" ]; then \
		xdg-open reports/report.html 2>/dev/null || open reports/report.html 2>/dev/null || echo "Open reports/report.html in your browser"; \
	else \
		echo "No test report found. Run 'make test' first."; \
	fi

# Development helpers
dev-up:
	docker-compose up -d

dev-down:
	docker-compose down

dev-logs:
	docker-compose logs -f

# Database helpers
db-shell:
	docker exec -it cleaning_tracker_db_test psql -U cleaning_user -d cleaning_tracker_test

db-reset:
	docker-compose -f docker-compose.test.yml exec postgres-test psql -U cleaning_user -d cleaning_tracker_test -c "SELECT api.reset_test_data();"