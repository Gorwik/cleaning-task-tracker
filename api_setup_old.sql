-- This file should be run AFTER init.sql
-- It sets up PostgREST API access and authentication

-- Create API user and roles
CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
CREATE ROLE api_anon;
CREATE ROLE api_authenticated;

-- Grant basic permissions
GRANT api_anon TO api_user;
GRANT api_authenticated TO api_user;

-- Create API schema (separate from public schema for security)
CREATE SCHEMA IF NOT EXISTS api;
GRANT USAGE ON SCHEMA api TO api_anon, api_authenticated;

-- Create views in API schema for controlled access to data
-- 1. Current task assignments with user and task details
CREATE OR REPLACE VIEW api.current_assignments AS
SELECT 
    ta.id,
    ta.task_id,
    t.name as task_name,
    t.category,
    t.description,
    t.estimated_duration_minutes,
    ta.assigned_user_id,
    u.username as assigned_to,
    ta.assigned_at,
    ta.due_date,
    CASE 
        WHEN ta.due_date IS NOT NULL AND ta.due_date < CURRENT_TIMESTAMP 
        THEN true 
        ELSE false 
    END as is_overdue
FROM task_assignments ta
JOIN users u ON ta.assigned_user_id = u.id
JOIN tasks t ON ta.task_id = t.id
WHERE ta.is_active = true;

-- 2. Task completion history with reviews
CREATE OR REPLACE VIEW api.completion_history AS
SELECT 
    tc.id,
    tc.task_assignment_id,
    t.name as task_name,
    t.category,
    tc.completed_by_user_id,
    u.username as completed_by,
    tc.completed_at,
    tc.notes,
    tc.status,
    -- Aggregate review information
    COUNT(tr.id) as review_count,
    COUNT(CASE WHEN tr.approved = true THEN 1 END) as approvals,
    COUNT(CASE WHEN tr.approved = false THEN 1 END) as rejections,
    AVG(tr.rating) as average_rating
FROM task_completions tc
JOIN task_assignments ta ON tc.task_assignment_id = ta.id
JOIN tasks t ON ta.task_id = t.id
JOIN users u ON tc.completed_by_user_id = u.id
LEFT JOIN task_reviews tr ON tc.id = tr.task_completion_id
GROUP BY tc.id, t.name, t.category, tc.completed_by_user_id, u.username, 
         tc.completed_at, tc.notes, tc.status;

-- 3. User dashboard view
CREATE OR REPLACE VIEW api.user_dashboard AS
SELECT 
    u.id,
    u.username,
    -- Current assignments
    COUNT(CASE WHEN ta.is_active = true THEN 1 END) as current_tasks,
    COUNT(CASE WHEN ta.is_active = true AND ta.due_date < CURRENT_TIMESTAMP THEN 1 END) as overdue_tasks,
    -- Completion stats (last 30 days)
    COUNT(CASE WHEN tc.completed_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 1 END) as tasks_completed_month,
    -- Review stats
    AVG(CASE WHEN tr.reviewed_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN tr.rating END) as avg_rating_month,
    -- Notification preferences
    CASE WHEN u.email IS NOT NULL OR u.phone IS NOT NULL THEN true ELSE false END as notifications_enabled
FROM users u
LEFT JOIN task_assignments ta ON u.id = ta.assigned_user_id
LEFT JOIN task_completions tc ON u.id = tc.completed_by_user_id
LEFT JOIN task_reviews tr ON tc.id = tr.task_completion_id
GROUP BY u.id, u.username, u.email, u.phone;

-- 4. Tasks that need review
CREATE OR REPLACE VIEW api.pending_reviews AS
SELECT 
    tc.id as completion_id,
    t.name as task_name,
    t.category,
    tc.completed_by_user_id,
    completed_by.username as completed_by,
    tc.completed_at,
    tc.notes,
    -- Who can review (other roommates)
    array_agg(reviewer.id) as potential_reviewers,
    array_agg(reviewer.username) as potential_reviewer_names
FROM task_completions tc
JOIN task_assignments ta ON tc.task_assignment_id = ta.id
JOIN tasks t ON ta.task_id = t.id
JOIN users completed_by ON tc.completed_by_user_id = completed_by.id
CROSS JOIN users reviewer
WHERE tc.status = 'pending_review'
  AND reviewer.id != tc.completed_by_user_id  -- Can't review your own work
  AND NOT EXISTS (  -- Haven't reviewed this completion yet
      SELECT 1 FROM task_reviews tr 
      WHERE tr.task_completion_id = tc.id 
      AND tr.reviewer_user_id = reviewer.id
  )
GROUP BY tc.id, t.name, t.category, tc.completed_by_user_id, 
         completed_by.username, tc.completed_at, tc.notes;

-- Grant permissions on views
GRANT SELECT ON api.current_assignments TO api_anon, api_authenticated;
GRANT SELECT ON api.completion_history TO api_anon, api_authenticated;
GRANT SELECT ON api.user_dashboard TO api_anon, api_authenticated;
GRANT SELECT ON api.pending_reviews TO api_anon, api_authenticated;

-- Functions for API operations
-- 1. Complete a task
CREATE OR REPLACE FUNCTION api.complete_task(
    task_assignment_id INTEGER,
    completed_by_user_id INTEGER,
    notes TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    result JSON;
    completion_id INTEGER;
    next_user_id INTEGER;
    current_task_id INTEGER;
BEGIN
    -- Get current task info
    SELECT ta.task_id INTO current_task_id
    FROM task_assignments ta 
    WHERE ta.id = task_assignment_id;
    
    -- Insert completion record
    INSERT INTO task_completions (task_assignment_id, completed_by_user_id, notes)
    VALUES (task_assignment_id, completed_by_user_id, notes)
    RETURNING id INTO completion_id;
    
    -- Find next user in a round-robin fashion
    SELECT u.id INTO next_user_id
    FROM (
        SELECT 
            id,
            LEAD(id, 1, (SELECT MIN(id) FROM users)) OVER (ORDER BY id) as next_id
        FROM users
    ) AS u_ordered
    JOIN users u ON u_ordered.next_id = u.id
    WHERE u_ordered.id = completed_by_user_id;
    
    -- Create next assignment (inactive until approved)
    INSERT INTO task_assignments (task_id, assigned_user_id, is_active)
    VALUES (current_task_id, next_user_id, false);
    
    -- Return completion details
    SELECT json_build_object(
        'completion_id', completion_id,
        'status', 'pending_review',
        'message', 'Task completed! Waiting for roommate review.'
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Review a completed task
CREATE OR REPLACE FUNCTION api.review_task(
    completion_id INTEGER,
    reviewer_user_id INTEGER,
    approved BOOLEAN,
    rating INTEGER DEFAULT NULL,
    comments TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    result JSON;
    assignment_id INTEGER;
    task_id_var INTEGER;
    completed_user_id INTEGER;
    next_user_id INTEGER;
BEGIN
    -- Insert review
    INSERT INTO task_reviews (task_completion_id, reviewer_user_id, approved, rating, comments)
    VALUES (completion_id, reviewer_user_id, approved, rating, comments);
    
    -- Get the task assignment ID and task ID
    SELECT tc.task_assignment_id, ta.task_id 
    INTO assignment_id, task_id_var
    FROM task_completions tc
    JOIN task_assignments ta ON tc.task_assignment_id = ta.id
    WHERE tc.id = completion_id;
    
    -- If approved, handle task rotation
    IF approved THEN
        -- Deactivate current assignment
        UPDATE task_assignments 
        SET is_active = false 
        WHERE id = assignment_id;
        
        -- Get the user who completed the task
        SELECT completed_by_user_id INTO completed_user_id
        FROM task_completions
        WHERE id = completion_id;

        -- Find the next user in a round-robin fashion
        SELECT u.id INTO next_user_id
        FROM (
            SELECT 
                id,
                LEAD(id, 1, (SELECT MIN(id) FROM users)) OVER (ORDER BY id) as next_id
            FROM users
        ) AS u_ordered
        JOIN users u ON u_ordered.next_id = u.id
        WHERE u_ordered.id = completed_by_user_id;

        -- Activate the specific next assignment
        UPDATE task_assignments 
        SET is_active = true, assigned_at = CURRENT_TIMESTAMP
        WHERE task_id = task_id_var 
          AND assigned_user_id = next_user_id
          AND is_active = false
          AND id = (SELECT MAX(id) FROM task_assignments WHERE task_id = task_id_var AND assigned_user_id = next_user_id AND is_active = false);
        
        -- Update completion status
        UPDATE task_completions 
        SET status = 'approved' 
        WHERE id = completion_id;
        
        SELECT json_build_object(
            'status', 'approved',
            'message', 'Task approved! Assignment rotated to next roommate.'
        ) INTO result;
    ELSE
        -- Update completion status
        UPDATE task_completions 
        SET status = 'rejected' 
        WHERE id = completion_id;
        
        SELECT json_build_object(
            'status', 'rejected',
            'message', 'Task rejected. Please redo the task.'
        ) INTO result;
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION api.complete_task TO api_authenticated;
GRANT EXECUTE ON FUNCTION api.review_task TO api_authenticated;

-- Enable RLS (Row Level Security) for future authentication
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- For now, allow all access (we'll add proper RLS policies later)
CREATE POLICY allow_all_users ON users FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_assignments ON task_assignments FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_completions ON task_completions FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_reviews ON task_reviews FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_notifications ON notifications FOR ALL TO api_anon, api_authenticated USING (true);

-- Create a simple login function (we'll improve this later)
CREATE OR REPLACE FUNCTION api.login(p_username TEXT, p_password TEXT) 
RETURNS JSON AS $$
DECLARE
    user_record RECORD;
    token TEXT;
BEGIN
    SELECT id, username INTO user_record
    FROM users 
    WHERE users.username = p_username 
      AND users.password_hash = crypt(p_password, users.password_hash);
    
    IF user_record.id IS NULL THEN
        RETURN json_build_object('error', 'Invalid credentials');
    END IF;
    
    -- For now, return a simple token (in production, use proper JWT)
    token := encode(digest(user_record.id::text || user_record.username || extract(epoch from now())::text, 'sha256'), 'hex');
    
    RETURN json_build_object(
        'user_id', user_record.id,
        'username', user_record.username,
        'token', token,
        'message', 'Login successful'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION api.login TO api_anon;