-- Test-specific data setup
-- This runs after init.sql and api_setup.sql

-- Create additional test users for comprehensive testing
INSERT INTO users (username, email, phone, password_hash) VALUES
('testuser1', 'testuser1@example.com', '+1111111111', crypt('testpass123', gen_salt('bf'))),
('testuser2', 'testuser2@example.com', '+2222222222', crypt('testpass123', gen_salt('bf'))),
('testuser3', NULL, NULL, crypt('testpass123', gen_salt('bf'))),
('reviewer1', 'reviewer1@example.com', '+3333333333', crypt('reviewpass123', gen_salt('bf'))),
('reviewer2', 'reviewer2@example.com', '+4444444444', crypt('reviewpass123', gen_salt('bf')));

-- Create additional test tasks
INSERT INTO tasks (name, category, description, estimated_duration_minutes) VALUES
('Test Kitchen Deep Clean', 'cleaning', 'Deep clean kitchen for testing', 90),
('Test Trash Collection', 'trash', 'Collect all trash for testing', 20),
('Test Bathroom Sanitize', 'cleaning', 'Sanitize bathroom for testing', 40),
('Test Paper Sorting', 'trash', 'Sort paper recycling for testing', 10);

-- Set up some completed tasks for testing history
WITH test_assignments AS (
    INSERT INTO task_assignments (task_id, assigned_user_id, is_active)
    SELECT 
        (SELECT id FROM tasks WHERE name = 'Test Kitchen Deep Clean'),
        (SELECT id FROM users WHERE username = 'testuser1'),
        false
    RETURNING id
),
test_completions AS (
    INSERT INTO task_completions (task_assignment_id, completed_by_user_id, notes, status)
    SELECT 
        ta.id,
        (SELECT id FROM users WHERE username = 'testuser1'),
        'Test completion notes - kitchen was very clean',
        'approved'
    FROM test_assignments ta
    RETURNING id, task_assignment_id
)
INSERT INTO task_reviews (task_completion_id, reviewer_user_id, rating, comments, approved, reviewed_at)
SELECT 
    tc.id,
    (SELECT id FROM users WHERE username = 'reviewer1'),
    5,
    'Excellent work on the kitchen!',
    true,
    CURRENT_TIMESTAMP - INTERVAL '1 day'
FROM test_completions tc;

-- Create some pending completions for review testing
WITH pending_assignment AS (
    INSERT INTO task_assignments (task_id, assigned_user_id, is_active)
    SELECT 
        (SELECT id FROM tasks WHERE name = 'Test Bathroom Sanitize'),
        (SELECT id FROM users WHERE username = 'testuser2'),
        false
    RETURNING id
)
INSERT INTO task_completions (task_assignment_id, completed_by_user_id, notes, status)
SELECT 
    pa.id,
    (SELECT id FROM users WHERE username = 'testuser2'),
    'Bathroom cleaned and sanitized thoroughly',
    'pending_review'
FROM pending_assignment pa;

-- Create some test notifications
INSERT INTO notifications (user_id, type, title, message, created_at) VALUES
((SELECT id FROM users WHERE username = 'testuser1'), 'task_assigned', 'New Task Assigned', 'You have been assigned: Mixed Trash', CURRENT_TIMESTAMP - INTERVAL '2 hours'),
((SELECT id FROM users WHERE username = 'testuser2'), 'task_completed', 'Task Completed', 'testuser1 completed: Kitchen Cleaning', CURRENT_TIMESTAMP - INTERVAL '1 hour'),
((SELECT id FROM users WHERE username = 'reviewer1'), 'review_requested', 'Review Requested', 'Please review completed task: Bathroom Sanitize', CURRENT_TIMESTAMP - INTERVAL '30 minutes');

-- Create function to reset test data between test runs
CREATE OR REPLACE FUNCTION api.reset_test_data() RETURNS void AS $$
BEGIN
    -- Delete test data in reverse dependency order
    DELETE FROM task_reviews WHERE task_completion_id IN (
        SELECT tc.id FROM task_completions tc
        JOIN task_assignments ta ON tc.task_assignment_id = ta.id
        JOIN users u ON tc.completed_by_user_id = u.id
        WHERE u.username LIKE 'testuser%' OR u.username LIKE 'reviewer%'
    );
    
    DELETE FROM task_completions WHERE task_assignment_id IN (
        SELECT ta.id FROM task_assignments ta
        JOIN users u ON ta.assigned_user_id = u.id
        WHERE u.username LIKE 'testuser%' OR u.username LIKE 'reviewer%'
    );
    
    DELETE FROM task_assignments WHERE assigned_user_id IN (
        SELECT id FROM users WHERE username LIKE 'testuser%' OR username LIKE 'reviewer%'
    );
    
    DELETE FROM notifications WHERE user_id IN (
        SELECT id FROM users WHERE username LIKE 'testuser%' OR username LIKE 'reviewer%'
    );
    
    -- Don't delete users and tasks as they're needed for structure
    
    -- Reset sequences if needed
    -- ALTER SEQUENCE task_assignments_id_seq RESTART WITH 1;
    -- ALTER SEQUENCE task_completions_id_seq RESTART WITH 1;
    -- ALTER SEQUENCE task_reviews_id_seq RESTART WITH 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION api.reset_test_data TO api_authenticated;