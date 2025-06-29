-- This file will contain the API functions (RPC calls) for PostgREST.
-- We will add functions here in Phase 2.

-- Create views in API schema for controlled access to data
-- 1. Users view (exclude sensitive data like password_hash)
CREATE OR REPLACE VIEW api.users AS
SELECT 
    user_id,
    username,
    created_at
FROM public.users;

-- 2. Tasks view
CREATE OR REPLACE VIEW api.tasks AS
SELECT 
    task_id,
    task_name,
    description
FROM public.tasks;

-- 3. Task assignments view with user and task details
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
FROM public.task_assignments ta
JOIN public.users u ON ta.user_id = u.user_id
JOIN public.tasks t ON ta.task_id = t.task_id;

-- Grant permissions on views
GRANT SELECT ON api.users TO api_anon, api_authenticated;
GRANT SELECT ON api.tasks TO api_anon, api_authenticated;
GRANT SELECT ON api.task_assignments TO api_anon, api_authenticated;

-- Authentication Functions
-- 1. User Registration Function
CREATE OR REPLACE FUNCTION api.register_user(p_username TEXT, p_password TEXT)
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. User Login Function
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT)
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
  FROM public.users 
  WHERE username = p_username 
    AND password_hash = crypt(p_password, password_hash);
  
  IF v_user_record.user_id IS NULL THEN
    PERFORM set_config('response.status', '401', true);
    RETURN json_build_object('error', 'Invalid credentials');
  END IF;

  -- Return user info (simple approach without JWT for now)
  RETURN json_build_object(
    'user_id', v_user_record.user_id,
    'username', v_user_record.username,
    'message', 'Login successful'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION api.register_user TO api_anon;
GRANT EXECUTE ON FUNCTION api.login TO api_anon;