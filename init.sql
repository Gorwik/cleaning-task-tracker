-- Create a dedicated schema for our API
CREATE SCHEMA api;

-- Create roles for the application
-- api_user will be used by PostgREST to connect to the database
CREATE ROLE api_user LOGIN PASSWORD 'api_pass';
-- api_anon will be the role for anonymous users
CREATE ROLE api_anon nologin;
-- api_authenticated will be the role for authenticated users
CREATE ROLE api_authenticated nologin;

-- Grant usage on the schema to the new roles
GRANT USAGE ON SCHEMA api TO api_user, api_anon, api_authenticated;
GRANT USAGE ON SCHEMA public TO api_user, api_anon, api_authenticated;

-- Grant basic permissions
GRANT api_anon TO api_user;
GRANT api_authenticated TO api_user;

-- Grant api_user role to the cleaning_user so it can switch to it
GRANT api_user TO cleaning_user;

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Define the core tables in the 'public' schema
CREATE TABLE IF NOT EXISTS public.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tasks (
    task_id SERIAL PRIMARY KEY,
    task_name VARCHAR(255) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE IF NOT EXISTS public.task_assignments (
    assignment_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES public.tasks(task_id),
    user_id INT NOT NULL REFERENCES public.users(user_id),
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    -- null = not reviewed, true = approved, false = rejected
    is_approved BOOLEAN DEFAULT NULL,
    UNIQUE(task_id, user_id, completed_at) -- A user can be assigned the same task multiple times, but not if the last one isn't completed.
);

-- Grant permissions for the anonymous role on our tables
GRANT SELECT ON TABLE public.users TO api_anon, api_authenticated;
GRANT SELECT ON TABLE public.tasks TO api_anon, api_authenticated;
GRANT SELECT ON TABLE public.task_assignments TO api_anon, api_authenticated;

-- Grant permissions for the authenticated user role
GRANT ALL ON TABLE public.users TO api_user;
GRANT ALL ON TABLE public.tasks TO api_user;
GRANT ALL ON TABLE public.task_assignments TO api_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO api_user;

-- Seed initial data
-- Passwords are 'password123' hashed with pgcrypto
INSERT INTO public.users (username, password_hash) VALUES
('user1', crypt('password123', gen_salt('bf'))),
('user2', crypt('password123', gen_salt('bf'))),
('user3', crypt('password123', gen_salt('bf')));

INSERT INTO public.tasks (task_name, description) VALUES
('Kitchen Cleaning', 'Clean the kitchen surfaces and floor.'),
('Bathroom Cleaning', 'Clean the toilet, shower, and sink.'),
('Living Room Tidying', 'Tidy up the living room area.'),
('Trash Duty', 'Take out the trash and recycling.'),
('Vacuuming', 'Vacuum all carpets and rugs.'),
('Dishwashing', 'Wash all dirty dishes.');

-- Staggered initial assignments for testing
INSERT INTO public.task_assignments (task_id, user_id) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 1),
(5, 2),
(6, 3);

-- Enable RLS (Row Level Security) for authentication
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

-- For now, allow all access (we'll add proper RLS policies later)
CREATE POLICY allow_all_users ON public.users FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_tasks ON public.tasks FOR ALL TO api_anon, api_authenticated USING (true);
CREATE POLICY allow_all_assignments ON public.task_assignments FOR ALL TO api_anon, api_authenticated USING (true);
