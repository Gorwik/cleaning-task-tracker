# Knowledge Base - Cleaning Task Tracker

## 1. PostgREST RPC/Function Calls

This guide provides concrete examples for creating and calling PostgreSQL functions via the PostgREST API, which is the core mechanism for our application's logic.

### **1.1. Calling Functions with Named Parameters (The Standard Method)**

This is the **preferred method** for our project. It avoids ambiguity and is self-documenting.

**SQL Function Definition:**
- Use named parameters in the function signature.
- The function must be in the `api` schema.

```sql
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT)
RETURNS JSON AS $
BEGIN
  -- function logic here
END;
$ LANGUAGE plpgsql;
```

**HTTP `POST` Request:**
- **Endpoint:** `/rpc/{function_name}`
- **Headers:** `Content-Type: application/json`
- **Body:** A JSON object where keys are the **exact** parameter names from the function definition.

```json
POST /rpc/login
{
  "p_username": "testuser",
  "p_password": "password123"
}
```

**Common Errors & Solutions:**
- **`400 Bad Request` - "Could not find a function..."**:
    - **Cause:** The JSON keys in the request body do not match the function's parameter names, or the number of arguments is wrong.
    - **Solution:** Double-check that every key in the JSON payload exactly matches a parameter name in the `CREATE FUNCTION` statement.
- **`404 Not Found`**:
    - **Cause:** The function does not exist in the `api` schema, the schema is not exposed to PostgREST, or the function name in the URL is misspelled.
    - **Solution:** Verify the function exists in the `api` schema and that `PGRST_DB_SCHEMA` in `docker-compose.yml` includes `api`.

### **1.2. Functions with a Single JSON/JSONB Parameter**

This is useful for endpoints that accept complex or optional data.

**SQL Function Definition:**
- Define the function to accept a single `json` or `jsonb` parameter.

```sql
CREATE OR REPLACE FUNCTION api.update_user_profile(p_data JSONB)
RETURNS JSON AS $
DECLARE
  v_user_id INT;
  v_bio TEXT;
BEGIN
  v_user_id := (p_data->>'user_id')::INT;
  v_bio := p_data->>'bio';
  -- update logic...
END;
$ LANGUAGE plpgsql;
```

**HTTP `POST` Request:**
- **Endpoint:** `/rpc/{function_name}`
- **Body:** A JSON object where the *top-level key* matches the parameter name (`p_data`).

```json
POST /rpc/update_user_profile
{
  "p_data": {
    "user_id": 123,
    "bio": "New bio here."
  }
}
```

### **1.3. Returning Custom HTTP Statuses and Responses**

This is essential for providing meaningful feedback from the API (e.g., for authentication or validation).

**SQL Function Definition:**
- Use `set_config('response.status', '...', true)` to set the HTTP status code.
- Return a `JSON` object for the response body.

```sql
CREATE OR REPLACE FUNCTION api.create_item(p_name TEXT)
RETURNS JSON AS $
BEGIN
  IF p_name IS NULL OR LENGTH(p_name) < 3 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('message', 'Name must be at least 3 characters');
  END IF;

  -- insert logic...

  PERFORM set_config('response.status', '201', true); -- Created
  RETURN json_build_object('message', 'Item created successfully');
END;
$ LANGUAGE plpgsql;
```

**HTTP `POST` Request & Response:**
- **Request:** `POST /rpc/create_item` with `{"p_name": "ab"}`
- **Response:** `HTTP 400 Bad Request` with body `{"message": "Name must be at least 3 characters"}`

## 2. Password Hashing with pgcrypto

### **2.1. Basic Password Hashing**

```sql
-- Hash a password
SELECT crypt('password123', gen_salt('bf'));

-- Verify a password
SELECT (password_hash = crypt('password123', password_hash)) as is_valid
FROM users WHERE username = 'testuser';
```

### **2.2. User Registration Function**

```sql
CREATE OR REPLACE FUNCTION api.register_user(p_username TEXT, p_password TEXT)
RETURNS JSON AS $
DECLARE
  v_user_id INT;
BEGIN
  -- Check if username already exists
  IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Username already exists');
  END IF;

  -- Insert new user
  INSERT INTO public.users (username, password_hash)
  VALUES (p_username, crypt(p_password, gen_salt('bf')))
  RETURNING user_id INTO v_user_id;

  PERFORM set_config('response.status', '201', true);
  RETURN json_build_object(
    'user_id', v_user_id,
    'username', p_username,
    'message', 'User registered successfully'
  );
END;
$ LANGUAGE plpgsql;
```

### **2.3. Simple Login Function (without JWT)**

```sql
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT)
RETURNS JSON AS $
DECLARE
  v_user_record RECORD;
BEGIN
  -- Find user and verify password
  SELECT user_id, username INTO v_user_record
  FROM public.users 
  WHERE username = p_username 
    AND password_hash = crypt(p_password, password_hash);
  
  IF v_user_record.user_id IS NULL THEN
    PERFORM set_config('response.status', '401', true);
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  -- Return user info (simple approach without JWT)
  RETURN json_build_object(
    'user_id', v_user_record.user_id,
    'username', v_user_record.username,
    'message', 'Login successful'
  );
END;
$ LANGUAGE plpgsql;
```

## 3. Task Management Functions

### **3.1. Complete Task Function**

```sql
CREATE OR REPLACE FUNCTION api.complete_task(p_assignment_id INT, p_user_id INT, p_notes TEXT DEFAULT NULL)
RETURNS JSON AS $
DECLARE
  v_assignment RECORD;
BEGIN
  -- Check if assignment exists and belongs to user
  SELECT ta.*, t.task_name INTO v_assignment
  FROM public.task_assignments ta
  JOIN public.tasks t ON ta.task_id = t.task_id
  WHERE ta.assignment_id = p_assignment_id 
    AND ta.user_id = p_user_id
    AND ta.completed_at IS NULL;
  
  IF v_assignment.assignment_id IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'Assignment not found or not yours');
  END IF;

  -- Mark as completed
  UPDATE public.task_assignments 
  SET completed_at = NOW()
  WHERE assignment_id = p_assignment_id;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Task completed successfully',
    'task_name', v_assignment.task_name
  );
END;
$ LANGUAGE plpgsql;
```

### **3.2. Reject Task Function**

```sql
CREATE OR REPLACE FUNCTION api.reject_task(p_assignment_id INT, p_reviewer_id INT, p_reason TEXT DEFAULT NULL)
RETURNS JSON AS $
DECLARE
  v_assignment RECORD;
BEGIN
  -- Check if assignment exists and is completed
  SELECT ta.*, t.task_name INTO v_assignment
  FROM public.task_assignments ta
  JOIN public.tasks t ON ta.task_id = t.task_id
  WHERE ta.assignment_id = p_assignment_id 
    AND ta.completed_at IS NOT NULL
    AND ta.is_approved IS NULL;
  
  IF v_assignment.assignment_id IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'Assignment not found or not ready for review');
  END IF;

  -- Mark as rejected
  UPDATE public.task_assignments 
  SET is_approved = FALSE
  WHERE assignment_id = p_assignment_id;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Task rejected',
    'task_name', v_assignment.task_name
  );
END;
$ LANGUAGE plpgsql;
```

## 4. Frontend Serving from PostgreSQL

### **4.1. Research Findings**

**PostgREST Capabilities for Frontend Serving:**
- PostgREST can serve any content type through functions that return TEXT
- Functions can set custom HTTP headers using `set_config('response.headers', ...)`
- Content-Type can be controlled via function responses
- Static assets can be stored in database tables and served dynamically

**Best Practices for Frontend Serving:**
1. **Store HTML/CSS/JS in database tables** for version control and easy updates
2. **Use functions to serve content** with proper content-type headers
3. **Implement caching strategies** to avoid repeated database queries
4. **Serve different content types** (HTML, CSS, JS) through separate functions
5. **Use base64 encoding** for binary assets if needed

**Content-Type Headers for Different Assets:**
- HTML: `text/html; charset=utf-8`
- CSS: `text/css; charset=utf-8`
- JavaScript: `application/javascript; charset=utf-8`
- JSON: `application/json; charset=utf-8`

### **4.2. HTML Content Storage**

```sql
-- Table to store frontend assets
CREATE TABLE public.frontend_assets (
    asset_id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) UNIQUE NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_frontend_assets_updated_at
    BEFORE UPDATE ON public.frontend_assets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT SELECT ON public.frontend_assets TO api_anon, api_authenticated;
GRANT ALL ON public.frontend_assets TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO api_user;
```

### **4.3. Serve HTML Function**

```sql
CREATE OR REPLACE FUNCTION api.serve_html(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
  v_content_type TEXT;
BEGIN
  -- Get content and content type
  SELECT content, content_type INTO v_content, v_content_type
  FROM public.frontend_assets
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
```

### **4.4. Serve CSS Function**

```sql
CREATE OR REPLACE FUNCTION api.serve_css(p_asset_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  SELECT content INTO v_content
  FROM public.frontend_assets
  WHERE asset_name = p_asset_name AND content_type = 'text/css';
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'CSS asset not found';
  END IF;

  PERFORM set_config('response.headers', 'Content-Type: text/css; charset=utf-8', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=86400', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **4.5. Serve JavaScript Function**

```sql
CREATE OR REPLACE FUNCTION api.serve_js(p_asset_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  SELECT content INTO v_content
  FROM public.frontend_assets
  WHERE asset_name = p_asset_name AND content_type = 'application/javascript';
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'JavaScript asset not found';
  END IF;

  PERFORM set_config('response.headers', 'Content-Type: application/javascript; charset=utf-8', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=86400', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **4.6. Asset Management Functions**

```sql
-- Function to insert or update frontend assets
CREATE OR REPLACE FUNCTION api.update_frontend_asset(
  p_asset_name TEXT,
  p_content_type TEXT,
  p_content TEXT
)
RETURNS JSON AS $$
DECLARE
  v_asset_id INT;
BEGIN
  -- Validate inputs
  IF p_asset_name IS NULL OR p_content_type IS NULL OR p_content IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'All parameters are required');
  END IF;

  -- Insert or update the asset
  INSERT INTO public.frontend_assets (asset_name, content_type, content)
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

-- Function to list all frontend assets
CREATE OR REPLACE FUNCTION api.list_frontend_assets()
RETURNS JSON AS $$
DECLARE
  v_assets JSON;
BEGIN
  SELECT json_agg(json_build_object(
    'asset_id', asset_id,
    'asset_name', asset_name,
    'content_type', content_type,
    'created_at', created_at,
    'updated_at', updated_at
  )) INTO v_assets
  FROM public.frontend_assets
  ORDER BY asset_name;

  RETURN COALESCE(v_assets, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **4.7. Frontend Integration with API**

**JavaScript API Integration Pattern:**
```javascript
// Base API configuration
const API_BASE = 'http://localhost:3000';

// API client with error handling
class APIClient {
    static async request(endpoint, options = {}) {
        try {
            const response = await fetch(`${API_BASE}${endpoint}`, {
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                ...options
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error('API request failed:', error);
            throw error;
        }
    }

    static async login(username, password) {
        return this.request('/rpc/login', {
            method: 'POST',
            body: JSON.stringify({ p_username: username, p_password: password })
        });
    }

    static async getTasks() {
        return this.request('/tasks');
    }

    static async getAssignments() {
        return this.request('/task_assignments');
    }

    static async completeTask(assignmentId, userId, notes) {
        return this.request('/rpc/complete_task', {
            method: 'POST',
            body: JSON.stringify({
                p_assignment_id: assignmentId,
                p_user_id: userId,
                p_notes: notes
            })
        });
    }
}
```

### **4.8. Security Considerations for Frontend Serving**

**Content Security Policy (CSP):**
```sql
-- Function to serve HTML with CSP headers
CREATE OR REPLACE FUNCTION api.serve_html_secure(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
BEGIN
  SELECT content INTO v_content
  FROM public.frontend_assets
  WHERE asset_name = p_asset_name;
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;

  -- Set security headers
  PERFORM set_config('response.headers', 'Content-Type: text/html; charset=utf-8', true);
  PERFORM set_config('response.headers', 'X-Content-Type-Options: nosniff', true);
  PERFORM set_config('response.headers', 'X-Frame-Options: DENY', true);
  PERFORM set_config('response.headers', 'X-XSS-Protection: 1; mode=block', true);
  
  -- Add CSP header
  PERFORM set_config('response.headers', 'Content-Security-Policy: default-src ''self''; script-src ''self'' ''unsafe-inline''; style-src ''self'' ''unsafe-inline'';', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### **4.9. Performance Optimization**

**Caching Strategy:**
```sql
-- Function with ETag support for caching
CREATE OR REPLACE FUNCTION api.serve_html_cached(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $$
DECLARE
  v_content TEXT;
  v_etag TEXT;
BEGIN
  SELECT content, MD5(content) INTO v_content, v_etag
  FROM public.frontend_assets
  WHERE asset_name = p_asset_name;
  
  IF v_content IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN 'Asset not found';
  END IF;

  -- Set cache headers with ETag
  PERFORM set_config('response.headers', 'Content-Type: text/html; charset=utf-8', true);
  PERFORM set_config('response.headers', 'ETag: "' || v_etag || '"', true);
  PERFORM set_config('response.headers', 'Cache-Control: public, max-age=3600', true);
  
  RETURN v_content;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 5. pg_cron Scheduling

### **5.1. Basic Task Rotation Function**

```sql
-- Function to rotate task assignments
CREATE OR REPLACE FUNCTION api.rotate_task_assignments()
RETURNS VOID AS $
DECLARE
  v_task RECORD;
  v_next_user_id INT;
  v_total_users INT;
BEGIN
  -- Get total number of users
  SELECT COUNT(*) INTO v_total_users FROM public.users;
  
  -- For each active task
  FOR v_task IN 
    SELECT DISTINCT task_id 
    FROM public.task_assignments 
    WHERE completed_at IS NULL
  LOOP
    -- Find the next user in rotation
    SELECT user_id INTO v_next_user_id
    FROM public.task_assignments ta
    WHERE ta.task_id = v_task.task_id
    ORDER BY ta.assigned_at DESC
    LIMIT 1;
    
    -- Calculate next user (simple round-robin)
    v_next_user_id := ((v_next_user_id % v_total_users) + 1);
    
    -- Assign to next user
    INSERT INTO public.task_assignments (task_id, user_id)
    VALUES (v_task.task_id, v_next_user_id);
  END LOOP;
END;
$ LANGUAGE plpgsql;

-- Schedule the rotation (example: every Sunday at 9 AM)
-- SELECT cron.schedule('rotate-tasks', '0 9 * * 0', 'SELECT api.rotate_task_assignments();');
```

## 6. Testing Patterns

### **6.1. API Testing with pytest**

```python
import pytest
import requests

def test_login_success(api_client):
    response = api_client.post('/rpc/login', json={
        'p_username': 'user1',
        'p_password': 'password123'
    })
    assert response.status_code == 200
    data = response.json()
    assert 'user_id' in data
    assert data['username'] == 'user1'

def test_login_failure(api_client):
    response = api_client.post('/rpc/login', json={
        'p_username': 'user1',
        'p_password': 'wrongpassword'
    })
    assert response.status_code == 401
    data = response.json()
    assert 'error' in data
```

### **6.2. Database Testing**

```python
def test_user_creation(db_connection):
    with db_connection.cursor() as cursor:
        cursor.execute("""
            SELECT api.register_user('testuser', 'password123')
        """)
        result = cursor.fetchone()
        assert result[0]['user_id'] is not None
```

## 7. Docker and Environment Setup

### **7.1. Required Extensions**

```sql
-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_cron";
```

### **7.2. PostgREST Configuration**

```yaml
# docker-compose.yml environment variables
PGRST_DB_URI: postgres://api_user:api_pass@db:5432/cleaning_tracker
PGRST_DB_SCHEMAS: api,public
PGRST_DB_ANON_ROLE: api_anon
PGRST_DB_USE_LEGACY_GUCS: "false"
PGRST_LOG_LEVEL: info
```

### **7.3. Proper PostgREST Authentication Setup**

**Critical Configuration Requirements:**

1. **Three-Role System:**
```sql
-- Create all three required roles
CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
CREATE ROLE api_anon nologin;
CREATE ROLE api_authenticated nologin;

-- Grant roles to each other (CRITICAL)
GRANT api_anon TO api_user;
GRANT api_authenticated TO api_user;
```

2. **Schema Access:**
```sql
-- Grant usage on schemas to all roles
GRANT USAGE ON SCHEMA api TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA public TO api_user, api_anon, api_authenticated;
```

3. **Row Level Security (RLS):**
```sql
-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

-- Create policies for anonymous and authenticated access
CREATE POLICY allow_all_users ON public.users FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_tasks ON public.tasks FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_assignments ON public.task_assignments FOR ALL TO api_anon, api_authenticated USING (true);
```

4. **API Schema with Views:**
```sql
-- Create controlled views in api schema
CREATE OR REPLACE VIEW api.users AS
SELECT user_id, username, created_at
FROM public.users;

CREATE OR REPLACE VIEW api.tasks AS
SELECT task_id, task_name, description
FROM public.tasks;

-- Grant permissions on views
GRANT SELECT ON api.users TO api_anon, api_authenticated;
GRANT SELECT ON api.tasks TO api_anon, api_authenticated;
```

**Common Authentication Issues & Solutions:**

- **401 Unauthorized Errors:**
  - **Cause:** Missing role grants (`GRANT api_anon TO api_user`)
  - **Solution:** Ensure all three roles exist and are properly granted
  
- **Schema Access Issues:**
  - **Cause:** `api_anon` role doesn't have usage permission on schemas
  - **Solution:** Grant `USAGE` on both `api` and `public` schemas to all roles
  
- **RLS Blocking Access:**
  - **Cause:** Tables have RLS enabled but no policies
  - **Solution:** Create policies allowing access for `api_anon` and `api_authenticated`
  
- **Wrong Schema Configuration:**
  - **Cause:** PostgREST configured for `public` schema only
  - **Solution:** Use `PGRST_DB_SCHEMAS: api,public` and create views in `api` schema

## 8. PostgREST Troubleshooting

### **8.1. Debugging Authentication Issues**

**Step-by-Step Diagnosis:**

1. **Check Container Logs:**
```bash
docker logs cleaning_tracker_api
```

2. **Verify Database Connection:**
```bash
docker exec cleaning_tracker_db psql -U cleaning_user -d cleaning_tracker -c "\du"
```

3. **Check Role Permissions:**
```bash
docker exec cleaning_tracker_db psql -U cleaning_user -d cleaning_tracker -c "SELECT grantee, table_name, privilege_type FROM information_schema.role_table_grants WHERE grantee IN ('api_anon', 'api_user', 'api_authenticated');"
```

4. **Test API Endpoints:**
```bash
curl http://localhost:3000/users
curl http://localhost:3000/tasks
```

**Common Error Patterns:**

- **"FATAL: password authentication failed for user 'api_user'"**
  - **Solution:** Ensure `api_user` is created with `LOGIN PASSWORD 'api_pass'`
  
- **"401 Unauthorized" on all endpoints**
  - **Solution:** Check role grants and RLS policies
  
- **"MissingSchema: Invalid URL" in tests**
  - **Solution:** Fix `api_client` fixture to handle base URLs properly

### **8.2. Testing Configuration**

**Proper Test Setup:**
```python
@pytest.fixture(scope='module')
def api_client():
    """API client fixture for testing PostgREST endpoints."""
    base_url = "http://localhost:3000"
    
    # Wait for API to be ready
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get(f"{base_url}/")
            if response.status_code == 200:
                break
        except requests.exceptions.ConnectionError:
            if i == max_retries - 1:
                pytest.fail("API not accessible after 30 retries")
            time.sleep(1)
    
    # Create a session with the base URL configured
    session = requests.Session()
    
    # Override the request method to prepend base_url for relative URLs
    original_request = session.request
    
    def request_with_base_url(method, url, *args, **kwargs):
        if not url.startswith('http'):
            url = f"{base_url}{url}"
        return original_request(method, url, *args, **kwargs)
    
    session.request = request_with_base_url
    return session
```

## 9. Security Considerations

### **9.1. Input Validation**

```sql
-- Always validate inputs in functions
CREATE OR REPLACE FUNCTION api.safe_function(p_input TEXT)
RETURNS JSON AS $
BEGIN
  -- Validate input
  IF p_input IS NULL OR LENGTH(TRIM(p_input)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Input cannot be empty');
  END IF;
  
  -- Continue with function logic...
END;
$ LANGUAGE plpgsql;
```

### **9.2. SQL Injection Prevention**

- Use parameterized queries (PostgreSQL functions handle this automatically)
- Validate all inputs
- Use proper escaping for dynamic SQL (if needed)
- Limit function permissions with `SECURITY DEFINER` when appropriate 

## 9. Production-Ready Database Ownership Management

### **9.1. The Ownership Problem in Production**

**Current Development Issue:**
- Functions and tables are owned by `cleaning_user` (superuser)
- `api_user` cannot modify objects owned by `cleaning_user`
- Requires manual ownership changes or database rebuilds

**Production Requirements:**
- Zero-downtime deployments
- Automated schema migrations
- Proper role separation and security
- No manual database interventions

### **9.2. Production-Ready Solutions**

#### **Solution 1: Proper Role Hierarchy (Recommended)**

**Core Principle:** Create a dedicated application owner role that owns all application objects.

```sql
-- 1. Create Application Owner Role
CREATE ROLE app_owner LOGIN PASSWORD 'app_owner_pass';

-- 2. Create Application Schema
CREATE SCHEMA app_schema AUTHORIZATION app_owner;

-- 3. Create Application Tables with Proper Ownership
CREATE TABLE app_schema.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Create Functions with Proper Ownership
CREATE OR REPLACE FUNCTION app_schema.login(p_username TEXT, p_password TEXT)
RETURNS JSON AS $$
-- function body
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Grant Permissions to API Roles
GRANT USAGE ON SCHEMA app_schema TO api_user, api_anon, api_authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app_schema TO api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_schema TO api_user, api_anon, api_authenticated;
```

**Benefits:**
- Clean ownership hierarchy
- No ownership conflicts
- Proper security separation
- Easy to manage permissions

#### **Solution 2: Migration-Based Ownership Management**

**Core Principle:** Use database migrations to manage ownership changes.

```sql
-- Migration: 001_setup_ownership.sql
-- Run as superuser to establish proper ownership

-- 1. Create application owner if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_owner') THEN
        CREATE ROLE app_owner LOGIN PASSWORD 'app_owner_pass';
    END IF;
END
$$;

-- 2. Change ownership of existing objects
ALTER TABLE public.users OWNER TO app_owner;
ALTER TABLE public.tasks OWNER TO app_owner;
ALTER TABLE public.task_assignments OWNER TO app_owner;
ALTER TABLE public.frontend_assets OWNER TO app_owner;

-- 3. Change ownership of functions
ALTER FUNCTION api.register_user(TEXT, TEXT) OWNER TO app_owner;
ALTER FUNCTION api.login(TEXT, TEXT) OWNER TO app_owner;
-- ... repeat for all functions

-- 4. Grant necessary permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA api TO api_user, api_anon, api_authenticated;
```

**Benefits:**
- Version-controlled ownership changes
- Can be automated in CI/CD
- Rollback capability
- Production-safe

#### **Solution 3: Schema-Based Separation**

**Core Principle:** Use separate schemas for different ownership domains.

```sql
-- 1. Create separate schemas
CREATE SCHEMA app_data AUTHORIZATION app_owner;
CREATE SCHEMA app_functions AUTHORIZATION app_owner;
CREATE SCHEMA app_frontend AUTHORIZATION app_owner;

-- 2. Organize objects by schema
-- app_data: Tables and data
CREATE TABLE app_data.users (...);
CREATE TABLE app_data.tasks (...);

-- app_functions: API functions
CREATE FUNCTION app_functions.login(...) RETURNS JSON;

-- app_frontend: Frontend assets
CREATE TABLE app_frontend.assets (...);

-- 3. Create views in api schema for controlled access
CREATE OR REPLACE VIEW api.users AS
SELECT * FROM app_data.users;

-- 4. Grant permissions appropriately
GRANT USAGE ON SCHEMA app_data TO api_user, api_anon, api_authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA app_data TO api_user, api_anon, api_authenticated;
```

**Benefits:**
- Clear separation of concerns
- Easy to manage permissions per domain
- Scalable architecture
- Better security isolation

### **9.3. Production Deployment Strategy**

#### **Strategy 1: Blue-Green Deployment**

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: cleaning_tracker
      POSTGRES_USER: app_owner  # Use app_owner as primary user
      POSTGRES_PASSWORD: app_owner_pass
    volumes:
      - ./migrations:/docker-entrypoint-initdb.d
      - ./init.sql:/docker-entrypoint-initdb.d/01-init.sql
      - ./api_setup.sql:/docker-entrypoint-initdb.d/02-api_setup.sql
      - ./frontend_setup.sql:/docker-entrypoint-initdb.d/03-frontend_setup.sql
      - ./migrations:/migrations  # Additional migrations

  postgrest:
    image: postgrest/postgrest:v12.0.2
    environment:
      PGRST_DB_URI: postgres://api_user:api_pass@db:5432/cleaning_tracker
      PGRST_DB_SCHEMAS: api,app_data,app_functions,app_frontend
      PGRST_DB_ANON_ROLE: api_anon
```

#### **Strategy 2: Migration-Based Deployment**

```bash
#!/bin/bash
# deploy.sh - Production deployment script

# 1. Backup current database
pg_dump -h localhost -U app_owner cleaning_tracker > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Run migrations
for migration in migrations/*.sql; do
    echo "Running migration: $migration"
    psql -h localhost -U app_owner -d cleaning_tracker -f "$migration"
done

# 3. Restart services
docker-compose -f docker-compose.prod.yml restart postgrest

# 4. Verify deployment
curl -f http://localhost:3000/health || exit 1
```

### **9.4. Security Best Practices**

#### **Role-Based Access Control (RBAC)**

```sql
-- 1. Define clear role hierarchy
CREATE ROLE app_owner LOGIN PASSWORD 'app_owner_pass';
CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
CREATE ROLE api_anon nologin;
CREATE ROLE api_authenticated nologin;

-- 2. Grant roles to each other
GRANT api_anon TO api_user;
GRANT api_authenticated TO api_user;
GRANT api_user TO app_owner;

-- 3. Schema-level permissions
GRANT USAGE ON SCHEMA app_data TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA app_functions TO api_user, api_anon, api_authenticated;

-- 4. Object-level permissions
GRANT SELECT ON ALL TABLES IN SCHEMA app_data TO api_anon, api_authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA app_data TO api_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app_functions TO api_anon, api_authenticated;
```

#### **Row Level Security (RLS)**

```sql
-- Enable RLS on all tables
ALTER TABLE app_data.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.tasks ENABLE ROW LEVEL SECURITY;

-- Create policies for different access patterns
CREATE POLICY users_select_policy ON app_data.users
    FOR SELECT TO api_anon, api_authenticated
    USING (true);

CREATE POLICY users_insert_policy ON app_data.users
    FOR INSERT TO api_authenticated
    WITH CHECK (true);

CREATE POLICY tasks_user_policy ON app_data.tasks
    FOR ALL TO api_authenticated
    USING (assigned_user_id = current_setting('app.current_user_id')::int);
```

### **9.5. Monitoring and Maintenance**

#### **Ownership Monitoring**

```sql
-- Query to check object ownership
SELECT 
    schemaname,
    tablename,
    tableowner,
    CASE 
        WHEN tableowner = 'app_owner' THEN 'OK'
        ELSE 'NEEDS_ATTENTION'
    END as ownership_status
FROM pg_tables 
WHERE schemaname IN ('public', 'app_data', 'app_functions');

-- Query to check function ownership
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
WHERE n.nspname IN ('api', 'app_functions');
```

#### **Automated Ownership Fixes**

```sql
-- Script to fix ownership issues
DO $$
DECLARE
    obj_record RECORD;
BEGIN
    -- Fix table ownership
    FOR obj_record IN 
        SELECT schemaname, tablename 
        FROM pg_tables 
        WHERE tableowner != 'app_owner'
        AND schemaname IN ('public', 'app_data')
    LOOP
        EXECUTE format('ALTER TABLE %I.%I OWNER TO app_owner', 
                      obj_record.schemaname, obj_record.tablename);
    END LOOP;
    
    -- Fix function ownership
    FOR obj_record IN 
        SELECT n.nspname, p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        JOIN pg_roles r ON p.proowner = r.oid
        WHERE r.rolname != 'app_owner'
        AND n.nspname IN ('api', 'app_functions')
    LOOP
        EXECUTE format('ALTER FUNCTION %I.%I OWNER TO app_owner', 
                      obj_record.nspname, obj_record.proname);
    END LOOP;
END
$$;
```

### **9.6. Implementation Recommendations**

**For Development:**
- Use Solution 1 (Proper Role Hierarchy) for new development
- Implement schema-based separation early
- Use migration scripts for ownership changes

**For Production:**
- Implement Solution 2 (Migration-Based) for existing deployments
- Use blue-green deployment strategy
- Implement comprehensive monitoring
- Regular ownership audits

**Migration Path:**
1. Create `app_owner` role
2. Create separate schemas (`app_data`, `app_functions`, `app_frontend`)
3. Move existing objects to appropriate schemas
4. Update PostgREST configuration
5. Test thoroughly before production deployment 

# Backend API Inventory (as of Phase 1.2)

## Views (Exposed as REST Endpoints)

### 1. api.users
- Fields: user_id, username, created_at
- Example fetch:
  ```js
  fetch('http://localhost:3000/users')
  ```

### 2. api.tasks
- Fields: task_id, task_name, description
- Example fetch:
  ```js
  fetch('http://localhost:3000/tasks')
  ```

### 3. api.task_assignments
- Fields: assignment_id, task_id, task_name, description, user_id, assigned_to, assigned_at, completed_at, is_approved
- Example fetch:
  ```js
  fetch('http://localhost:3000/task_assignments')
  ```

## Functions (Exposed as RPC Endpoints)

### 1. register_user
- Path: `/rpc/register_user`
- Params: p_username (TEXT), p_password (TEXT)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/register_user', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'user', password: 'pass' })
  })
  ```

### 2. login
- Path: `/rpc/login`
- Params: p_username (TEXT), p_password (TEXT)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'user', password: 'pass' })
  })
  ```

### 3. create_task
- Path: `/rpc/create_task`
- Params: p_task_name (TEXT), p_description (TEXT)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/create_task', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ task_name: 'Task', description: 'Desc' })
  })
  ```

### 4. assign_task
- Path: `/rpc/assign_task`
- Params: p_task_id (INT), p_user_id (INT)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/assign_task', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ task_id: 1, user_id: 2 })
  })
  ```

### 5. complete_task
- Path: `/rpc/complete_task`
- Params: p_assignment_id (INT), p_user_id (INT), p_notes (TEXT, optional)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/complete_task', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ assignment_id: 1, user_id: 2, notes: 'Done' })
  })
  ```

### 6. reject_task
- Path: `/rpc/reject_task`
- Params: p_assignment_id (INT), p_reviewer_id (INT), p_reason (TEXT, optional)
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/reject_task', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ assignment_id: 1, reviewer_id: 2, reason: 'Not clean' })
  })
  ```

### 7. rotate_tasks
- Path: `/rpc/rotate_tasks`
- No params
- Example fetch:
  ```js
  fetch('http://localhost:3000/rpc/rotate_tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  })
  ``` 