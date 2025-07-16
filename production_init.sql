-- production_init.sql
-- Migration script: Schema and Role Creation for Production Readiness
-- This script should be run as a superuser or database owner.

-- 1. Create roles (idempotent)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        CREATE ROLE app_owner NOLOGIN;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_user') THEN
        CREATE ROLE api_user LOGIN PASSWORD 'REPLACE_ME_WITH_SECURE_PASSWORD';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_anon') THEN
        CREATE ROLE api_anon NOLOGIN;
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_authenticated') THEN
        CREATE ROLE api_authenticated NOLOGIN;
    END IF;
END $$;

-- 2. Create schemas (idempotent, owned by app_owner)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_data') THEN
        EXECUTE 'CREATE SCHEMA app_data AUTHORIZATION app_owner';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_functions') THEN
        EXECUTE 'CREATE SCHEMA app_functions AUTHORIZATION app_owner';
    END IF;
END $$;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'app_frontend') THEN
        EXECUTE 'CREATE SCHEMA app_frontend AUTHORIZATION app_owner';
    END IF;
END $$;

-- api schema may already exist; ensure ownership
ALTER SCHEMA api OWNER TO app_owner;

-- 3. Grant USAGE on all new schemas to API roles
GRANT USAGE ON SCHEMA app_data TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA app_functions TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA app_frontend TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA api TO api_user, api_anon, api_authenticated;

-- 4. Revoke unnecessary privileges from public
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- 5. (Optional) Grant CREATE on api schema to api_user if needed
GRANT CREATE ON SCHEMA api TO api_user;

-- End of migration script 