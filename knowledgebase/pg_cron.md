# pg_cron: Scheduling and Task Rotation

## Overview
pg_cron is used to schedule automated tasks (e.g., rotating cleaning assignments) in PostgreSQL.

## Enabling pg_cron
```sql
CREATE EXTENSION IF NOT EXISTS "pg_cron";
```

## Task Rotation Logic
- Use a function to rotate assignments among users
- Schedule the function to run at regular intervals (e.g., weekly)

**Example Function:**
```sql
CREATE OR REPLACE FUNCTION app_functions.rotate_task_assignments()
RETURNS VOID AS $$
DECLARE
  v_task RECORD;
  v_next_user_id INT;
  v_total_users INT;
BEGIN
  SELECT COUNT(*) INTO v_total_users FROM app_data.users;
  FOR v_task IN 
    SELECT DISTINCT task_id 
    FROM app_data.task_assignments 
    WHERE completed_at IS NULL
  LOOP
    SELECT user_id INTO v_next_user_id
    FROM app_data.task_assignments ta
    WHERE ta.task_id = v_task.task_id
    ORDER BY ta.assigned_at DESC
    LIMIT 1;
    v_next_user_id := ((v_next_user_id % v_total_users) + 1);
    INSERT INTO app_data.task_assignments (task_id, user_id)
    VALUES (v_task.task_id, v_next_user_id);
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## Scheduling with pg_cron
```sql
-- Schedule the rotation (example: every Sunday at 9 AM)
SELECT cron.schedule('rotate-tasks', '0 9 * * 0', 'SELECT app_functions.rotate_task_assignments();');
```

## Troubleshooting
- Ensure pg_cron is enabled and loaded
- Check cron jobs with `SELECT * FROM cron.job;`
- Review logs for errors

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 