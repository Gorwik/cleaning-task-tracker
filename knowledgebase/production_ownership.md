# Production-Ready Database Ownership, Schema Separation, and Migration

## Overview
Proper ownership and schema separation are critical for secure, maintainable, and production-ready PostgreSQL deployments.

## Role Hierarchy & Schema Separation
- `app_owner`: Owns all schemas and objects in production
- `api_user`: Used by PostgREST for API access
- `api_anon`, `api_authenticated`: For anonymous and authenticated API access
- `app_data`: All tables and data
- `app_functions`: Business logic functions
- `app_frontend`: Frontend assets
- `api`: API views and exposed functions

## Initialization & Migration
- Use a single, idempotent initialization script for new production deployments
- For existing databases, use migration scripts to change ownership and move objects

**Example Initialization:**
See `production_init.sql` and `production_api_setup.sql` for full examples.

## Deployment Strategies
- Blue-Green Deployment: Use separate environments for zero-downtime
- Migration-Based Deployment: Use versioned migration scripts
- Automated health checks and monitoring scripts

## Monitoring & Maintenance
- Automated scripts to check and fix ownership
- Regular audits of schema, function, and table ownership
- Monitoring scripts for health and permissions

## Security Best Practices
- All objects owned by `app_owner`
- Grant only necessary privileges to API roles
- Use schema separation for security and clarity
- Automate migrations and initialization in CI/CD
- Implement RLS on all tables

## See Also
- [PRODUCTION_GUIDE.md](../PRODUCTION_GUIDE.md)
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 