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

### **4.1. HTML Content Storage**

```sql
-- Table to store frontend assets
CREATE TABLE public.frontend_assets (
    asset_id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) UNIQUE NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert the main HTML file
INSERT INTO public.frontend_assets (asset_name, content_type, content) VALUES
('index.html', 'text/html', '<!DOCTYPE html>...');
```

### **4.2. Serve HTML Function**

```sql
CREATE OR REPLACE FUNCTION api.serve_html(p_asset_name TEXT DEFAULT 'index.html')
RETURNS TEXT AS $
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

  -- Set HTML content type
  PERFORM set_config('response.headers', 'Content-Type: text/html', true);
  RETURN v_content;
END;
$ LANGUAGE plpgsql;
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