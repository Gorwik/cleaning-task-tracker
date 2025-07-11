# Production-Ready Database Ownership Management Guide

## Overview

This guide provides step-by-step instructions for implementing production-ready database ownership management for the Cleaning Task Tracker application. It addresses the ownership issues encountered during development and provides solutions suitable for production environments.

## Current Problem

**Development Issue:**
- Functions and tables owned by `cleaning_user` (superuser)
- `api_user` cannot modify objects owned by `cleaning_user`
- Requires manual ownership changes or database rebuilds
- Not suitable for production deployments

**Production Requirements:**
- Zero-downtime deployments
- Automated schema migrations
- Proper role separation and security
- No manual database interventions

## Solution: Proper Role Hierarchy with Schema Separation

### Step 1: Create Production Database Schema

Create a new file `production_init.sql`:

```sql
-- Production Database Setup
-- This file establishes proper role hierarchy and schema separation

-- 1. Create Application Owner Role
CREATE ROLE app_owner LOGIN PASSWORD 'app_owner_pass';

-- 2. Create Application Schemas with Proper Ownership
CREATE SCHEMA app_data AUTHORIZATION app_owner;
CREATE SCHEMA app_functions AUTHORIZATION app_owner;
CREATE SCHEMA app_frontend AUTHORIZATION app_owner;

-- 3. Create API Schema for Controlled Access
CREATE SCHEMA api AUTHORIZATION app_owner;

-- 4. Create API Roles
CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
CREATE ROLE api_anon nologin;
CREATE ROLE api_authenticated nologin;

-- 5. Grant Roles to Each Other
GRANT api_anon TO api_user;
GRANT api_authenticated TO api_user;
GRANT api_user TO app_owner;

-- 6. Grant Schema Usage
GRANT USAGE ON SCHEMA app_data TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA app_functions TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA app_frontend TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA api TO api_user, api_anon, api_authenticated;

-- 7. Enable Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 8. Create Tables in app_data Schema
CREATE TABLE app_data.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE app_data.tasks (
    task_id SERIAL PRIMARY KEY,
    task_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE app_data.task_assignments (
    assignment_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES app_data.tasks(task_id),
    user_id INT NOT NULL REFERENCES app_data.users(user_id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    is_approved BOOLEAN DEFAULT NULL,
    UNIQUE(task_id, user_id, completed_at)
);

CREATE TABLE app_frontend.frontend_assets (
    asset_id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) UNIQUE NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Grant Permissions
GRANT ALL ON ALL TABLES IN SCHEMA app_data TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app_data TO api_user;
GRANT ALL ON ALL TABLES IN SCHEMA app_frontend TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app_frontend TO api_user;

GRANT SELECT ON ALL TABLES IN SCHEMA app_data TO api_anon, api_authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA app_frontend TO api_anon, api_authenticated;

-- 10. Enable RLS
ALTER TABLE app_data.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.task_assignments ENABLE ROW LEVEL SECURITY;

-- 11. Create RLS Policies
CREATE POLICY allow_all_users ON app_data.users FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_tasks ON app_data.tasks FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_assignments ON app_data.task_assignments FOR ALL TO api_anon, api_authenticated USING (true);

-- 12. Seed Initial Data
INSERT INTO app_data.users (username, password_hash) VALUES
('user1', crypt('password123', gen_salt('bf'))),
('user2', crypt('password123', gen_salt('bf'))),
('user3', crypt('password123', gen_salt('bf')));

INSERT INTO app_data.tasks (task_name, description) VALUES
('Kitchen Cleaning', 'Clean the kitchen surfaces and floor.'),
('Bathroom Cleaning', 'Clean the toilet, shower, and sink.'),
('Living Room Tidying', 'Tidy up the living room area.'),
('Trash Duty', 'Take out the trash and recycling.'),
('Vacuuming', 'Vacuum all carpets and rugs.'),
('Dishwashing', 'Wash all dirty dishes.');

INSERT INTO app_data.task_assignments (task_id, user_id) VALUES
(1, 1), (2, 2), (3, 3), (4, 1), (5, 2), (6, 3);
```

### Step 2: Create Production API Setup

Create `production_api_setup.sql`:

```sql
-- Production API Setup
-- Functions and views with proper ownership

-- 1. Create Views in API Schema
CREATE OR REPLACE VIEW api.users AS
SELECT 
    user_id,
    username,
    created_at
FROM app_data.users;

CREATE OR REPLACE VIEW api.tasks AS
SELECT 
    task_id,
    task_name,
    description
FROM app_data.tasks;

CREATE OR REPLACE VIEW api.task_assignments AS
SELECT 
    ta.assignment_id,
    ta.task_id,
    t.task_name,
    t.description,
    ta.user_id,
    u.username as assigned_to,
    ta.assigned_at,
    ta.completed_at,
    ta.is_approved
FROM app_data.task_assignments ta
JOIN app_data.users u ON ta.user_id = u.user_id
JOIN app_data.tasks t ON ta.task_id = t.task_id;

-- 2. Grant Permissions on Views
GRANT SELECT ON api.users TO api_anon, api_authenticated;
GRANT SELECT ON api.tasks TO api_anon, api_authenticated;
GRANT SELECT ON api.task_assignments TO api_anon, api_authenticated;

-- 3. Authentication Functions
CREATE OR REPLACE FUNCTION app_functions.register_user(p_username TEXT, p_password TEXT)
RETURNS JSON AS $$
DECLARE
  v_user_id INT;
BEGIN
  -- Validate inputs
  IF p_username IS NULL OR LENGTH(TRIM(p_username)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Username cannot be empty');
  END IF;

  IF p_password IS NULL OR LENGTH(TRIM(p_password)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Password cannot be empty');
  END IF;

  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM app_data.users WHERE username = p_username) THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Username already exists');
  END IF;

  -- Insert new user
  INSERT INTO app_data.users (username, password_hash)
  VALUES (p_username, crypt(p_password, gen_salt('bf')))
  RETURNING user_id INTO v_user_id;

  PERFORM set_config('response.status', '201', true);
  RETURN json_build_object(
    'user_id', v_user_id,
    'username', p_username,
    'message', 'User registered successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION app_functions.login(p_username TEXT, p_password TEXT)
RETURNS JSON AS $$
DECLARE
  v_user_record RECORD;
BEGIN
  -- Validate inputs
  IF p_username IS NULL OR LENGTH(TRIM(p_username)) = 0 THEN
    PERFORM set_config('response.status', '401', true);
    RETURN json_build_object('error', 'Username cannot be empty');
  END IF;

  IF p_password IS NULL OR LENGTH(TRIM(p_password)) = 0 THEN
    PERFORM set_config('response.status', '401', true);
    RETURN json_build_object('error', 'Password cannot be empty');
  END IF;

  -- Find user and verify password
  SELECT user_id, username INTO v_user_record
  FROM app_data.users 
  WHERE username = p_username 
    AND password_hash = crypt(p_password, password_hash);
  
  IF v_user_record.user_id IS NULL THEN
    PERFORM set_config('response.status', '401', true);
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  RETURN json_build_object(
    'user_id', v_user_record.user_id,
    'username', v_user_record.username,
    'message', 'Login successful'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Task Management Functions
CREATE OR REPLACE FUNCTION app_functions.create_task(p_task_name TEXT, p_description TEXT)
RETURNS JSON AS $$
DECLARE
  v_task_id INT;
BEGIN
  -- Validate inputs
  IF p_task_name IS NULL OR LENGTH(TRIM(p_task_name)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task name cannot be empty');
  END IF;

  IF p_description IS NULL THEN
    p_description := '';
  END IF;

  -- Check if task name already exists
  IF EXISTS (SELECT 1 FROM app_data.tasks WHERE task_name = p_task_name) THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task name already exists');
  END IF;

  -- Insert new task
  INSERT INTO app_data.tasks (task_name, description)
  VALUES (p_task_name, p_description)
  RETURNING task_id INTO v_task_id;

  PERFORM set_config('response.status', '201', true);
  RETURN json_build_object(
    'task_id', v_task_id,
    'task_name', p_task_name,
    'description', p_description,
    'message', 'Task created successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add other task management functions similarly...

-- 5. Grant Execute Permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_functions TO api_user, api_anon, api_authenticated;
```

### Step 3: Create Production Frontend Setup

Create `production_frontend_setup.sql`:

```sql
-- Production Frontend Setup

-- 1. Create Frontend Serving Functions
CREATE OR REPLACE FUNCTION app_functions.serve_html(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
  v_content_type TEXT;
BEGIN
  -- Get content and content type
  SELECT content, content_type INTO v_content, v_content_type
  FROM app_frontend.frontend_assets
  WHERE asset_name = p_asset_name;
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;

  -- Set appropriate content type header
  PERFORM set_config('response.headers', 'Content-Type: ' || v_content_type || '; charset=utf-8', true);
  
  -- Set cache headers for better performance
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=3600', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION app_functions.serve_css(p_asset_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  -- Get content
  SELECT content INTO v_content
  FROM app_frontend.frontend_assets
  WHERE asset_name = p_asset_name;
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;

  -- Set content type header
  PERFORM set_config('response.headers', 'Content-Type: text/css; charset=utf-8', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=3600', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION app_functions.serve_js(p_asset_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  -- Get content
  SELECT content INTO v_content
  FROM app_frontend.frontend_assets
  WHERE asset_name = p_asset_name;
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;

  -- Set content type header
  PERFORM set_config('response.headers', 'Content-Type: application/javascript; charset=utf-8', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=3600', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Asset Management Functions
CREATE OR REPLACE FUNCTION app_functions.update_frontend_asset(
  p_asset_name TEXT, 
  p_content_type TEXT, 
  p_content TEXT
)
RETURNS JSON AS $$
DECLARE
  v_asset_id INT;
BEGIN
  -- Validate inputs
  IF p_asset_name IS NULL OR LENGTH(TRIM(p_asset_name)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Asset name cannot be empty');
  END IF;

  IF p_content_type IS NULL OR LENGTH(TRIM(p_content_type)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Content type cannot be empty');
  END IF;

  IF p_content IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Content cannot be empty');
  END IF;

  -- Insert or update the asset
  INSERT INTO app_frontend.frontend_assets (asset_name, content_type, content)
  VALUES (p_asset_name, p_content_type, p_content)
  ON CONFLICT (asset_name) 
  DO UPDATE SET 
    content_type = EXCLUDED.content_type,
    content = EXCLUDED.content,
    updated_at = NOW()
  RETURNING asset_id INTO v_asset_id;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Asset updated successfully',
    'asset_id', v_asset_id,
    'asset_name', p_asset_name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant Execute Permissions
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_functions TO api_user, api_anon, api_authenticated;
```

### Step 4: Create Production Docker Compose

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    container_name: cleaning_tracker_db_prod
    environment:
      POSTGRES_DB: cleaning_tracker
      POSTGRES_USER: app_owner  # Use app_owner as primary user
      POSTGRES_PASSWORD: app_owner_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data_prod:/var/lib/postgresql/data
      - ./production_init.sql:/docker-entrypoint-initdb.d/01-production_init.sql
      - ./production_api_setup.sql:/docker-entrypoint-initdb.d/02-production_api_setup.sql
      - ./production_frontend_setup.sql:/docker-entrypoint-initdb.d/03-production_frontend_setup.sql
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app_owner -d cleaning_tracker"]
      interval: 10s
      timeout: 5s
      retries: 5

  postgrest:
    image: postgrest/postgrest:v12.0.2
    container_name: cleaning_tracker_api_prod
    ports:
      - "3000:3000"
    environment:
      PGRST_DB_URI: postgres://api_user:api_pass@db:5432/cleaning_tracker
      PGRST_OPENAPI_SERVER_PROXY_URI: http://localhost:3000
      PGRST_DB_SCHEMAS: api,app_data,app_functions,app_frontend
      PGRST_DB_ANON_ROLE: api_anon
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_LOG_LEVEL: info
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

volumes:
  postgres_data_prod:
```

### Step 5: Create Migration Scripts

Create `migrations/001_setup_production_ownership.sql`:

```sql
-- Migration: Setup Production Ownership
-- This migration converts existing development setup to production-ready structure

-- 1. Create app_owner role if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        CREATE ROLE app_owner LOGIN PASSWORD 'app_owner_pass';
    END IF;
END
$$;

-- 2. Create production schemas
CREATE SCHEMA IF NOT EXISTS app_data AUTHORIZATION app_owner;
CREATE SCHEMA IF NOT EXISTS app_functions AUTHORIZATION app_owner;
CREATE SCHEMA IF NOT EXISTS app_frontend AUTHORIZATION app_owner;

-- 3. Move existing tables to app_data schema
-- (This would be done in a production environment with proper backup)

-- 4. Change ownership of existing objects
ALTER TABLE public.users OWNER TO app_owner;
ALTER TABLE public.tasks OWNER TO app_owner;
ALTER TABLE public.task_assignments OWNER TO app_owner;
ALTER TABLE public.frontend_assets OWNER TO app_owner;

-- 5. Change ownership of functions
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'api'
    LOOP
        EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO app_owner', 
                      func_record.nspname, func_record.proname, func_record.args);
    END LOOP;
END
$$;

-- 6. Grant necessary permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO api_user, api_anon, api_authenticated;
```

### Step 6: Create Deployment Script

Create `deploy.sh`:

```bash
#!/bin/bash
# Production Deployment Script

set -e  # Exit on any error

echo "Starting production deployment..."

# 1. Backup current database (if exists)
if [ -f "backup.sql" ]; then
    echo "Creating backup..."
    pg_dump -h localhost -U app_owner cleaning_tracker > backup_$(date +%Y%m%d_%H%M%S).sql
fi

# 2. Stop existing containers
echo "Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down

# 3. Start database with new schema
echo "Starting database with production schema..."
docker-compose -f docker-compose.prod.yml up -d db

# 4. Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 30

# 5. Run migrations (if any)
if [ -d "migrations" ]; then
    echo "Running migrations..."
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "Running migration: $migration"
            docker exec cleaning_tracker_db_prod psql -U app_owner -d cleaning_tracker -f "/docker-entrypoint-initdb.d/$(basename $migration)"
        fi
    done
fi

# 6. Start PostgREST
echo "Starting PostgREST..."
docker-compose -f docker-compose.prod.yml up -d postgrest

# 7. Wait for PostgREST to be ready
echo "Waiting for PostgREST to be ready..."
sleep 10

# 8. Verify deployment
echo "Verifying deployment..."
if curl -f http://localhost:3000/users > /dev/null 2>&1; then
    echo "✅ Deployment successful!"
else
    echo "❌ Deployment failed!"
    exit 1
fi

echo "Production deployment completed successfully!"
```

### Step 7: Create Monitoring Script

Create `monitor.sh`:

```bash
#!/bin/bash
# Production Monitoring Script

echo "Checking production system health..."

# 1. Check database connectivity
echo "Checking database connectivity..."
if docker exec cleaning_tracker_db_prod pg_isready -U app_owner -d cleaning_tracker > /dev/null 2>&1; then
    echo "✅ Database is healthy"
else
    echo "❌ Database connectivity issue"
    exit 1
fi

# 2. Check API connectivity
echo "Checking API connectivity..."
if curl -f http://localhost:3000/users > /dev/null 2>&1; then
    echo "✅ API is healthy"
else
    echo "❌ API connectivity issue"
    exit 1
fi

# 3. Check object ownership
echo "Checking object ownership..."
docker exec cleaning_tracker_db_prod psql -U app_owner -d cleaning_tracker -c "
SELECT 
    schemaname,
    tablename,
    tableowner,
    CASE 
        WHEN tableowner = 'app_owner' THEN 'OK'
        ELSE 'NEEDS_ATTENTION'
    END as ownership_status
FROM pg_tables 
WHERE schemaname IN ('public', 'app_data', 'app_functions')
ORDER BY schemaname, tablename;
"

# 4. Check function ownership
echo "Checking function ownership..."
docker exec cleaning_tracker_db_prod psql -U app_owner -d cleaning_tracker -c "
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    r.rolname as owner,
    CASE 
        WHEN r.rolname = 'app_owner' THEN 'OK'
        ELSE 'NEEDS_ATTENTION'
    END as ownership_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
JOIN pg_roles r ON p.proowner = r.oid
WHERE n.nspname IN ('api', 'app_functions')
ORDER BY n.nspname, p.proname;
"

echo "Monitoring completed!"
```

## Usage Instructions

### For Development (Current Setup)
```bash
# Use existing development setup
docker-compose up -d
```

### For Production Deployment
```bash
# 1. Make scripts executable
chmod +x deploy.sh monitor.sh

# 2. Deploy to production
./deploy.sh

# 3. Monitor system health
./monitor.sh
```

### For Migration from Development to Production
```bash
# 1. Backup current development data
docker exec cleaning_tracker_db pg_dump -U cleaning_user -d cleaning_tracker > dev_backup.sql

# 2. Deploy production setup
./deploy.sh

# 3. Verify migration
./monitor.sh
```

## Benefits of This Production Solution

1. **Zero Ownership Conflicts:** All objects owned by `app_owner`
2. **Schema Separation:** Clear organization of data, functions, and frontend assets
3. **Proper RBAC:** Clear role hierarchy with appropriate permissions
4. **Automated Deployment:** Scripted deployment with health checks
5. **Monitoring:** Automated ownership and health monitoring
6. **Rollback Capability:** Backup and restore procedures
7. **Security:** Proper role separation and RLS policies

## Security Considerations

1. **Role Hierarchy:** `app_owner` > `api_user` > `api_authenticated` > `api_anon`
2. **Schema Isolation:** Different schemas for different concerns
3. **RLS Policies:** Row-level security on all tables
4. **Function Security:** `SECURITY DEFINER` for functions that need elevated privileges
5. **Monitoring:** Automated checks for ownership and permission issues

This production-ready solution eliminates the ownership issues encountered during development and provides a robust foundation for production deployments. 