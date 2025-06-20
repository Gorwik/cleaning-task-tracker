-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table (your roommates)
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE, -- Optional for notifications
    phone VARCHAR(20), -- Optional for notifications
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task types (trash: mixed, plastic, paper; cleaning: bathroom, kitchen, floors)
CREATE TABLE tasks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(20) NOT NULL CHECK (category IN ('trash', 'cleaning')),
    description TEXT,
    estimated_duration_minutes INTEGER DEFAULT 30,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Current task assignments (who's turn is it?)
CREATE TABLE task_assignments (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id),
    assigned_user_id INTEGER NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    due_date TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(task_id, is_active) -- Only one active assignment per task
);

-- Task completion records
CREATE TABLE task_completions (
    id SERIAL PRIMARY KEY,
    task_assignment_id INTEGER NOT NULL REFERENCES task_assignments(id),
    completed_by_user_id INTEGER NOT NULL REFERENCES users(id),
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    photo_url VARCHAR(500), -- Optional: photo proof
    status VARCHAR(20) DEFAULT 'pending_review' CHECK (status IN ('pending_review', 'approved', 'rejected')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task reviews (roommates can approve/reject completed tasks)
CREATE TABLE task_reviews (
    id SERIAL PRIMARY KEY,
    task_completion_id INTEGER NOT NULL REFERENCES task_completions(id),
    reviewer_user_id INTEGER NOT NULL REFERENCES users(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comments TEXT,
    approved BOOLEAN NOT NULL,
    reviewed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(task_completion_id, reviewer_user_id) -- Each user can review once per completion
);

-- Notification queue (for SMS/email notifications)
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    type VARCHAR(50) NOT NULL, -- 'task_assigned', 'task_overdue', 'task_completed', 'review_requested'
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    sent_via VARCHAR(20) CHECK (sent_via IN ('email', 'sms', 'both')), -- Optional: only if notification sent
    sent_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN DEFAULT FALSE
);

-- Insert initial data
INSERT INTO users (username, email, phone, password_hash) VALUES
('roommate1', 'roommate1@example.com', '+1234567890', crypt('password123', gen_salt('bf'))),
('roommate2', NULL, NULL, crypt('password123', gen_salt('bf'))), -- No notifications
('roommate3', 'roommate3@example.com', '+1234567892', crypt('password123', gen_salt('bf')));

INSERT INTO tasks (name, category, description, estimated_duration_minutes) VALUES
('Mixed Trash', 'trash', 'Take out mixed/general waste trash', 15),
('Plastic Recycling', 'trash', 'Take out plastic recycling', 15),
('Paper Recycling', 'trash', 'Take out paper recycling', 15),
('Bathroom Cleaning', 'cleaning', 'Clean bathroom: toilet, sink, shower, floor', 45),
('Kitchen Cleaning', 'cleaning', 'Clean kitchen: dishes, counters, stove, floor', 60),
('Floor Cleaning', 'cleaning', 'Vacuum/mop common area floors', 30);

-- Create initial task assignments (round-robin style)
WITH numbered_tasks AS (
    SELECT id, name, ROW_NUMBER() OVER (ORDER BY name) as rn
    FROM tasks
),
numbered_users AS (
    SELECT id, username, ROW_NUMBER() OVER (ORDER BY username) as rn
    FROM users
)
INSERT INTO task_assignments (task_id, assigned_user_id)
SELECT 
    t.id, 
    u.id
FROM numbered_tasks t
JOIN numbered_users u ON ((t.rn - 1) % 3) + 1 = u.rn;

-- Create indexes for better performance
CREATE INDEX idx_task_assignments_active ON task_assignments(task_id, is_active);
CREATE INDEX idx_task_completions_status ON task_completions(status);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to users table
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();