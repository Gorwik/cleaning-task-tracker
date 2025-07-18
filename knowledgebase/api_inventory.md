# Backend API Inventory

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

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 