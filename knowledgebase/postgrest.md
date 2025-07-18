# PostgREST: API, Configuration, Patterns, and Troubleshooting

## Overview
PostgREST provides a RESTful API directly from PostgreSQL database schemas, enabling rapid, secure, and schema-driven API development.

## Configuration
- Expose only the necessary schemas (e.g., `api`, `app_data`) via `PGRST_DB_SCHEMAS`.
- Use a dedicated API user (`api_user`) with least-privilege access.
- Set `PGRST_DB_ANON_ROLE` to `api_anon` for unauthenticated access.

**Example docker-compose.yml:**
```yaml
PGRST_DB_URI: postgres://api_user:api_pass@db:5432/cleaning_tracker
PGRST_DB_SCHEMAS: api,app_data
PGRST_DB_ANON_ROLE: api_anon
PGRST_DB_USE_LEGACY_GUCS: "false"
PGRST_LOG_LEVEL: info
```

## Authentication & Roles
- Three-role system: `api_user`, `api_anon`, `api_authenticated`.
- Grant roles to each other as needed:
  ```sql
  GRANT api_anon TO api_user;
  GRANT api_authenticated TO api_user;
  ```
- Use RLS and policies to control access.

## Exposing Functions (RPC)
- Functions must be in the `api` schema to be exposed as `/rpc/{function}` endpoints.
- Use named parameters for clarity and compatibility.

**Example:**
```sql
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT)
RETURNS JSON AS $$
-- ...
$$ LANGUAGE plpgsql;
```

**Calling Functions:**
- Use HTTP POST to `/rpc/{function}` with JSON body matching parameter names.
- Example:
  ```json
  POST /rpc/login
  {
    "p_username": "testuser",
    "p_password": "password123"
  }
  ```

## Returning Custom HTTP Statuses
- Use `set_config('response.status', '...', true)` in SQL to set HTTP status code.
- Return a JSON object for the response body.

## Common Errors & Solutions
- **401 Unauthorized:** Check role grants and RLS policies.
- **404 Not Found:** Function/view not in exposed schema or misspelled.
- **400 Bad Request:** JSON keys in request body do not match function parameters.
- **"FATAL: password authentication failed for user 'api_user'":** Ensure `api_user` is created with `LOGIN PASSWORD`.

## Best Practices
- Use views in the `api` schema to control data exposure.
- Grant only `SELECT` on views to API roles.
- Use `SECURITY DEFINER` for functions that require privilege escalation.
- Always validate inputs in functions.

## Troubleshooting
- Check PostgREST logs for errors.
- Use `docker logs` and `psql` to verify role and schema setup.
- Test API endpoints with curl or HTTP client.

## API Inventory (as of Phase 1.2)

### Views (Exposed as REST Endpoints)
- `api.users`, `api.tasks`, `api.task_assignments`

### Functions (Exposed as RPC Endpoints)
- `register_user`, `login`, `create_task`, `assign_task`, `complete_task`, `reject_task`, `rotate_tasks`

See [api_inventory.md](./api_inventory.md) for full endpoint details and examples.

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 