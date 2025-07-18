-- production_init.sql
-- Production-ready initialization script for Cleaning Task Tracker
-- This script creates all roles, schemas, tables, views, functions, RLS, and permissions in their final production state.
-- Run as a superuser or database owner.
-- 1. Create roles (idempotent)
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'app_owner'
) THEN CREATE ROLE app_owner NOLOGIN;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'api_user'
) THEN CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'api_anon'
) THEN CREATE ROLE api_anon NOLOGIN;
END IF;
END $$;
DO $$ BEGIN IF NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = 'api_authenticated'
) THEN CREATE ROLE api_authenticated NOLOGIN;
END IF;
END $$;
-- 2. Create schemas (owned by app_owner)
CREATE SCHEMA IF NOT EXISTS app_data AUTHORIZATION app_owner;
CREATE SCHEMA IF NOT EXISTS app_functions AUTHORIZATION app_owner;
CREATE SCHEMA IF NOT EXISTS api AUTHORIZATION app_owner;
-- 3. Grant schema usage
GRANT USAGE ON SCHEMA app_data TO api_user,
    api_anon,
    api_authenticated;
GRANT USAGE ON SCHEMA app_functions TO api_user,
    api_anon,
    api_authenticated;
GRANT USAGE ON SCHEMA api TO api_user,
    api_anon,
    api_authenticated;
-- 4. Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- 5. Create tables in app_data
CREATE TABLE IF NOT EXISTS app_data.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS app_data.tasks (
    task_id SERIAL PRIMARY KEY,
    task_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT
);
CREATE TABLE IF NOT EXISTS app_data.task_assignments (
    assignment_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES app_data.tasks(task_id),
    user_id INT NOT NULL REFERENCES app_data.users(user_id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    is_approved BOOLEAN DEFAULT NULL,
    UNIQUE(task_id, user_id, completed_at)
);
-- 6. Grant table privileges
GRANT ALL ON ALL TABLES IN SCHEMA app_data TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app_data TO api_user;
GRANT SELECT ON ALL TABLES IN SCHEMA app_data TO api_anon,
    api_authenticated;
-- 7. Seed initial data
INSERT INTO app_data.users (username, password_hash)
VALUES ('user1', crypt('password123', gen_salt('bf'))),
    ('user2', crypt('password123', gen_salt('bf'))),
    ('user3', crypt('password123', gen_salt('bf'))) ON CONFLICT (username) DO NOTHING;
INSERT INTO app_data.tasks (task_name, description)
VALUES (
        'Kitchen Cleaning',
        'Clean the kitchen surfaces and floor.'
    ),
    (
        'Bathroom Cleaning',
        'Clean the toilet, shower, and sink.'
    ),
    (
        'Living Room Tidying',
        'Tidy up the living room area.'
    ),
    (
        'Trash Duty',
        'Take out the trash and recycling.'
    ),
    ('Vacuuming', 'Vacuum all carpets and rugs.'),
    ('Dishwashing', 'Wash all dirty dishes.') ON CONFLICT (task_name) DO NOTHING;
INSERT INTO app_data.task_assignments (task_id, user_id)
VALUES (1, 1),
    (2, 2),
    (3, 3),
    (4, 1),
    (5, 2),
    (6, 3) ON CONFLICT DO NOTHING;
-- 8. Enable RLS
ALTER TABLE app_data.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.task_assignments ENABLE ROW LEVEL SECURITY;
-- 9. RLS policies (permissive for now; tighten as needed)
CREATE POLICY IF NOT EXISTS allow_all_users ON app_data.users FOR ALL TO api_anon,
api_authenticated USING (true);
CREATE POLICY IF NOT EXISTS allow_all_tasks ON app_data.tasks FOR ALL TO api_anon,
api_authenticated USING (true);
CREATE POLICY IF NOT EXISTS allow_all_assignments ON app_data.task_assignments FOR ALL TO api_anon,
api_authenticated USING (true);
-- 10. Create views in api schema
CREATE OR REPLACE VIEW api.users AS
SELECT user_id,
    username,
    created_at
FROM app_data.users;
CREATE OR REPLACE VIEW api.tasks AS
SELECT task_id,
    task_name,
    description
FROM app_data.tasks;
CREATE OR REPLACE VIEW api.task_assignments AS
SELECT ta.assignment_id,
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
GRANT SELECT ON api.users TO api_anon,
    api_authenticated;
GRANT SELECT ON api.tasks TO api_anon,
    api_authenticated;
GRANT SELECT ON api.task_assignments TO api_anon,
    api_authenticated;
-- 11. Create API functions in api schema
-- User Registration
CREATE OR REPLACE FUNCTION api.register_user(p_username TEXT, p_password TEXT) RETURNS JSON AS $$
DECLARE v_user_id INT;
BEGIN IF p_username IS NULL
OR LENGTH(TRIM(p_username)) = 0 THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Username cannot be empty');
END IF;
IF p_password IS NULL
OR LENGTH(TRIM(p_password)) = 0 THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Password cannot be empty');
END IF;
IF EXISTS (
    SELECT 1
    FROM app_data.users
    WHERE username = p_username
) THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Username already exists');
END IF;
INSERT INTO app_data.users (username, password_hash)
VALUES (p_username, crypt(p_password, gen_salt('bf')))
RETURNING user_id INTO v_user_id;
PERFORM set_config('response.status', '201', true);
RETURN json_build_object(
    'user_id',
    v_user_id,
    'username',
    p_username,
    'message',
    'User registered successfully'
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- User Login
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT) RETURNS JSON AS $$
DECLARE v_user_record RECORD;
BEGIN IF p_username IS NULL
OR LENGTH(TRIM(p_username)) = 0 THEN PERFORM set_config('response.status', '401', true);
RETURN json_build_object('error', 'Username cannot be empty');
END IF;
IF p_password IS NULL
OR LENGTH(TRIM(p_password)) = 0 THEN PERFORM set_config('response.status', '401', true);
RETURN json_build_object('error', 'Password cannot be empty');
END IF;
SELECT user_id,
    username INTO v_user_record
FROM app_data.users
WHERE username = p_username
    AND password_hash = crypt(p_password, password_hash);
IF v_user_record.user_id IS NULL THEN PERFORM set_config('response.status', '401', true);
RETURN json_build_object('error', 'Invalid credentials');
END IF;
RETURN json_build_object(
    'user_id',
    v_user_record.user_id,
    'username',
    v_user_record.username,
    'message',
    'Login successful'
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION api.register_user TO api_anon;
GRANT EXECUTE ON FUNCTION api.login TO api_anon;
-- Create Task
CREATE OR REPLACE FUNCTION api.create_task(p_task_name TEXT, p_description TEXT) RETURNS JSON AS $$
DECLARE v_task_id INT;
BEGIN IF p_task_name IS NULL
OR LENGTH(TRIM(p_task_name)) = 0 THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task name cannot be empty');
END IF;
IF p_description IS NULL THEN p_description := '';
END IF;
IF EXISTS (
    SELECT 1
    FROM app_data.tasks
    WHERE task_name = p_task_name
) THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task name already exists');
END IF;
INSERT INTO app_data.tasks (task_name, description)
VALUES (p_task_name, p_description)
RETURNING task_id INTO v_task_id;
PERFORM set_config('response.status', '201', true);
RETURN json_build_object(
    'task_id',
    v_task_id,
    'task_name',
    p_task_name,
    'description',
    p_description,
    'message',
    'Task created successfully'
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Assign Task
CREATE OR REPLACE FUNCTION api.assign_task(p_task_id INT, p_user_id INT) RETURNS JSON AS $$
DECLARE v_assignment_id INT;
v_task_name TEXT;
v_username TEXT;
BEGIN IF p_task_id IS NULL
OR p_user_id IS NULL THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task ID and User ID are required');
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM app_data.tasks
    WHERE task_id = p_task_id
) THEN PERFORM set_config('response.status', '404', true);
RETURN json_build_object('error', 'Task not found');
END IF;
IF NOT EXISTS (
    SELECT 1
    FROM app_data.users
    WHERE user_id = p_user_id
) THEN PERFORM set_config('response.status', '404', true);
RETURN json_build_object('error', 'User not found');
END IF;
IF EXISTS (
    SELECT 1
    FROM app_data.task_assignments
    WHERE task_id = p_task_id
        AND completed_at IS NULL
) THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task is already assigned to a user');
END IF;
SELECT task_name INTO v_task_name
FROM app_data.tasks
WHERE task_id = p_task_id;
SELECT username INTO v_username
FROM app_data.users
WHERE user_id = p_user_id;
INSERT INTO app_data.task_assignments (task_id, user_id)
VALUES (p_task_id, p_user_id)
RETURNING assignment_id INTO v_assignment_id;
PERFORM set_config('response.status', '201', true);
RETURN json_build_object(
    'assignment_id',
    v_assignment_id,
    'task_id',
    p_task_id,
    'user_id',
    p_user_id,
    'task_name',
    v_task_name,
    'username',
    v_username,
    'message',
    'Task assigned successfully'
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Complete Task
CREATE OR REPLACE FUNCTION api.complete_task(
        p_assignment_id INT,
        p_user_id INT,
        p_notes TEXT DEFAULT NULL
    ) RETURNS JSON AS $$
DECLARE v_assignment RECORD;
v_task_name TEXT;
BEGIN IF p_assignment_id IS NULL
OR p_user_id IS NULL THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object(
    'error',
    'Assignment ID and User ID are required'
);
END IF;
SELECT ta.*,
    t.task_name INTO v_assignment
FROM app_data.task_assignments ta
    JOIN app_data.tasks t ON ta.task_id = t.task_id
WHERE ta.assignment_id = p_assignment_id;
IF v_assignment.assignment_id IS NULL THEN PERFORM set_config('response.status', '404', true);
RETURN json_build_object('error', 'Assignment not found');
END IF;
IF v_assignment.user_id != p_user_id THEN PERFORM set_config('response.status', '403', true);
RETURN json_build_object('error', 'You can only complete your own tasks');
END IF;
IF v_assignment.completed_at IS NOT NULL
AND v_assignment.is_approved IS DISTINCT
FROM FALSE THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task is already completed');
END IF;
IF v_assignment.is_approved = FALSE THEN
UPDATE app_data.task_assignments
SET is_approved = NULL
WHERE assignment_id = p_assignment_id;
END IF;
UPDATE app_data.task_assignments
SET completed_at = NOW()
WHERE assignment_id = p_assignment_id;
PERFORM set_config('response.status', '200', true);
RETURN json_build_object(
    'message',
    'Task completed successfully',
    'task_name',
    v_assignment.task_name,
    'completed_at',
    NOW()
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Reject Task
CREATE OR REPLACE FUNCTION api.reject_task(
        p_assignment_id INT,
        p_reviewer_id INT,
        p_reason TEXT DEFAULT NULL
    ) RETURNS JSON AS $$
DECLARE v_assignment RECORD;
v_task_name TEXT;
BEGIN IF p_assignment_id IS NULL
OR p_reviewer_id IS NULL THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object(
    'error',
    'Assignment ID and Reviewer ID are required'
);
END IF;
SELECT ta.*,
    t.task_name INTO v_assignment
FROM app_data.task_assignments ta
    JOIN app_data.tasks t ON ta.task_id = t.task_id
WHERE ta.assignment_id = p_assignment_id;
IF v_assignment.assignment_id IS NULL THEN PERFORM set_config('response.status', '404', true);
RETURN json_build_object('error', 'Assignment not found');
END IF;
IF v_assignment.completed_at IS NULL THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object(
    'error',
    'Task must be completed before it can be rejected'
);
END IF;
IF v_assignment.is_approved IS NOT NULL THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'Task has already been reviewed');
END IF;
UPDATE app_data.task_assignments
SET is_approved = FALSE
WHERE assignment_id = p_assignment_id;
PERFORM set_config('response.status', '200', true);
RETURN json_build_object(
    'message',
    'Task rejected successfully',
    'task_name',
    v_assignment.task_name,
    'reason',
    p_reason
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Rotate Tasks
CREATE OR REPLACE FUNCTION api.rotate_tasks() RETURNS JSON AS $$
DECLARE v_task RECORD;
v_next_user_id INT;
v_total_users INT;
v_rotation_count INT := 0;
BEGIN
SELECT COUNT(*) INTO v_total_users
FROM app_data.users;
IF v_total_users = 0 THEN PERFORM set_config('response.status', '400', true);
RETURN json_build_object('error', 'No users available for rotation');
END IF;
FOR v_task IN
SELECT DISTINCT t.task_id,
    t.task_name
FROM app_data.tasks t
    LEFT JOIN app_data.task_assignments ta ON t.task_id = ta.task_id
WHERE ta.assignment_id IS NULL
    OR (
        ta.completed_at IS NULL
        AND ta.is_approved IS NULL
    )
    OR (ta.is_approved = FALSE) LOOP
SELECT COALESCE(
        (
            SELECT user_id
            FROM app_data.task_assignments
            WHERE task_id = v_task.task_id
            ORDER BY assigned_at DESC
            LIMIT 1
        ), 0
    ) INTO v_next_user_id;
v_next_user_id := ((v_next_user_id % v_total_users) + 1);
INSERT INTO app_data.task_assignments (task_id, user_id)
VALUES (v_task.task_id, v_next_user_id);
v_rotation_count := v_rotation_count + 1;
END LOOP;
PERFORM set_config('response.status', '200', true);
RETURN json_build_object(
    'message',
    'Tasks rotated successfully',
    'rotated_count',
    v_rotation_count
);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Grant execute permissions on task functions
GRANT EXECUTE ON FUNCTION api.create_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.assign_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.complete_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.reject_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.rotate_tasks TO api_authenticated;