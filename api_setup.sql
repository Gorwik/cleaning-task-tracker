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
  IF EXISTS (SELECT 1 FROM public.users WHERE public.users.username = p_username) THEN
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
  WHERE public.users.username = p_username 
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

-- Task Management Functions
-- 1. Create Task Function
CREATE OR REPLACE FUNCTION api.create_task(p_task_name TEXT, p_description TEXT)
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
  IF EXISTS (SELECT 1 FROM public.tasks WHERE task_name = p_task_name) THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task name already exists');
  END IF;

  -- Insert new task
  INSERT INTO public.tasks (task_name, description)
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

-- 2. Assign Task Function
CREATE OR REPLACE FUNCTION api.assign_task(p_task_id INT, p_user_id INT)
RETURNS JSON AS $$
DECLARE
  v_assignment_id INT;
  v_task_name TEXT;
  v_username TEXT;
BEGIN
  -- Validate inputs
  IF p_task_id IS NULL OR p_user_id IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task ID and User ID are required');
  END IF;

  -- Check if task exists
  IF NOT EXISTS (SELECT 1 FROM public.tasks WHERE task_id = p_task_id) THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'Task not found');
  END IF;

  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE user_id = p_user_id) THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'User not found');
  END IF;

  -- Check if task is already assigned to anyone and not completed
  IF EXISTS (
    SELECT 1 FROM public.task_assignments 
    WHERE task_id = p_task_id 
      AND completed_at IS NULL
  ) THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task is already assigned to a user');
  END IF;

  -- Get task and user names for response
  SELECT task_name INTO v_task_name FROM public.tasks WHERE task_id = p_task_id;
  SELECT username INTO v_username FROM public.users WHERE user_id = p_user_id;

  -- Create assignment
  INSERT INTO public.task_assignments (task_id, user_id)
  VALUES (p_task_id, p_user_id)
  RETURNING assignment_id INTO v_assignment_id;

  PERFORM set_config('response.status', '201', true);
  RETURN json_build_object(
    'assignment_id', v_assignment_id,
    'task_id', p_task_id,
    'user_id', p_user_id,
    'task_name', v_task_name,
    'username', v_username,
    'message', 'Task assigned successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Complete Task Function
CREATE OR REPLACE FUNCTION api.complete_task(p_assignment_id INT, p_user_id INT, p_notes TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
  v_assignment RECORD;
  v_task_name TEXT;
BEGIN
  -- Validate inputs
  IF p_assignment_id IS NULL OR p_user_id IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Assignment ID and User ID are required');
  END IF;

  -- Get assignment details
  SELECT ta.*, t.task_name INTO v_assignment
  FROM public.task_assignments ta
  JOIN public.tasks t ON ta.task_id = t.task_id
  WHERE ta.assignment_id = p_assignment_id;

  -- Check if assignment exists
  IF v_assignment.assignment_id IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'Assignment not found');
  END IF;

  -- Check if user owns this assignment
  IF v_assignment.user_id != p_user_id THEN
    PERFORM set_config('response.status', '403', true);
    RETURN json_build_object('error', 'You can only complete your own tasks');
  END IF;

  -- Check if already completed
  IF v_assignment.completed_at IS NOT NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task is already completed');
  END IF;

  -- Mark as completed
  UPDATE public.task_assignments 
  SET completed_at = NOW()
  WHERE assignment_id = p_assignment_id;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Task completed successfully',
    'task_name', v_assignment.task_name,
    'completed_at', NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Reject Task Function
CREATE OR REPLACE FUNCTION api.reject_task(p_assignment_id INT, p_reviewer_id INT, p_reason TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
  v_assignment RECORD;
  v_task_name TEXT;
BEGIN
  -- Validate inputs
  IF p_assignment_id IS NULL OR p_reviewer_id IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Assignment ID and Reviewer ID are required');
  END IF;

  -- Get assignment details
  SELECT ta.*, t.task_name INTO v_assignment
  FROM public.task_assignments ta
  JOIN public.tasks t ON ta.task_id = t.task_id
  WHERE ta.assignment_id = p_assignment_id;

  -- Check if assignment exists
  IF v_assignment.assignment_id IS NULL THEN
    PERFORM set_config('response.status', '404', true);
    RETURN json_build_object('error', 'Assignment not found');
  END IF;

  -- Check if task is completed
  IF v_assignment.completed_at IS NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task must be completed before it can be rejected');
  END IF;

  -- Check if already reviewed
  IF v_assignment.is_approved IS NOT NULL THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Task has already been reviewed');
  END IF;

  -- Mark as rejected
  UPDATE public.task_assignments 
  SET is_approved = FALSE
  WHERE assignment_id = p_assignment_id;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Task rejected successfully',
    'task_name', v_assignment.task_name,
    'reason', p_reason
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Rotate Tasks Function
CREATE OR REPLACE FUNCTION api.rotate_tasks()
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
  v_next_user_id INT;
  v_total_users INT;
  v_rotation_count INT := 0;
BEGIN
  -- Get total number of users
  SELECT COUNT(*) INTO v_total_users FROM public.users;
  
  IF v_total_users = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'No users available for rotation');
  END IF;

  -- For each active task (not completed or not rejected)
  FOR v_task IN 
    SELECT DISTINCT t.task_id, t.task_name
    FROM public.tasks t
    LEFT JOIN public.task_assignments ta ON t.task_id = ta.task_id
    WHERE ta.assignment_id IS NULL 
       OR (ta.completed_at IS NULL AND ta.is_approved IS NULL)
       OR (ta.is_approved = FALSE)  -- Rejected tasks need reassignment
  LOOP
    -- Find the next user in rotation
    SELECT COALESCE(
      (SELECT user_id FROM public.task_assignments 
       WHERE task_id = v_task.task_id 
       ORDER BY assigned_at DESC 
       LIMIT 1), 0
    ) INTO v_next_user_id;
    
    -- Calculate next user (simple round-robin)
    v_next_user_id := ((v_next_user_id % v_total_users) + 1);
    
    -- Assign to next user
    INSERT INTO public.task_assignments (task_id, user_id)
    VALUES (v_task.task_id, v_next_user_id);
    
    v_rotation_count := v_rotation_count + 1;
  END LOOP;

  PERFORM set_config('response.status', '200', true);
  RETURN json_build_object(
    'message', 'Tasks rotated successfully',
    'rotated_count', v_rotation_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on task functions
GRANT EXECUTE ON FUNCTION api.create_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.assign_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.complete_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.reject_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.rotate_tasks TO api_authenticated;