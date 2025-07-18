# Docker & Environment Setup

## Overview
Docker is used to manage the PostgreSQL and PostgREST services for development and production.

## docker-compose.yml Example
```yaml
version: '3.8'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: cleaning_tracker
      POSTGRES_USER: cleaning_user
      POSTGRES_PASSWORD: cleaning_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql
      - ./api_setup.sql:/docker-entrypoint-initdb.d/02-api_setup.sql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U cleaning_user -d cleaning_tracker"]
      interval: 10s
      timeout: 5s
      retries: 5
  postgrest:
    image: postgrest/postgrest:v12.0.2
    ports:
      - "3000:3000"
    environment:
      PGRST_DB_URI: postgres://api_user:api_pass@db:5432/cleaning_tracker
      PGRST_DB_SCHEMAS: api,public
      PGRST_DB_ANON_ROLE: api_anon
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_LOG_LEVEL: info
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
volumes:
  postgres_data:
```

## Health Checks
- Use `pg_isready` for database health
- Use curl or HTTP client for API health

## Deployment & Monitoring
- Use blue-green deployment for zero downtime
- Use monitoring scripts to check health, ownership, and permissions

## Troubleshooting
- Check container logs with `docker logs`
- Use `psql` to verify roles, schemas, and permissions
- Ensure all environment variables are set correctly

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 