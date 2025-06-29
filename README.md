# Cleaning Task Tracker

## 1. Project Overview

This application aims to digitalize and streamline the process of tracking cleaning tasks among roommates. Leveraging PostgreSQL as the primary backend, it will manage task assignments, completion tracking, review processes, and notifications. A unique aspect of this project is serving the frontend (HTML, CSS, JavaScript) directly from the PostgreSQL database to minimize external dependencies.

## 2. Core Features & Requirements

### User & Authentication
- **Authentication:** Users must log in with a username and password.
- **Authorization:** Users can only mark their own assigned tasks as complete.

### Task Management
- **Task Completion:** Users can mark their assigned tasks as "done."
- **Progress Visibility:** All users can see the status of all tasks.
- **Review System:** A review process allows users to "reject" a completed task, marking it as needing correction. This process is similar to a GitHub review.

### Turn & Schedule Management
- **Automated Rotation:** Turns for tasks will rotate automatically and sequentially among users.
- **Staggered Start:** At first run, task assignments will be staggered.
- **Availability:** The system must handle cases where a user is on vacation and cannot complete a task.

### Notifications
- **Channels:** The system should be capable of sending SMS and email notifications (implementation details to be defined later).

## 3. Tech Stack & Knowledge Base

### 3.1. Tech Stack

- **Primary Backend:** PostgreSQL
- **API Layer:** PostgREST (to provide a RESTful API directly from the database).
- **Authentication:** `pg_jwt` extension for managing JSON Web Tokens.
- **Scheduling:** `pg_cron` extension for automated tasks (e.g., turn rotation).
- **Frontend:** HTML, CSS, and JavaScript served directly from PostgreSQL.
- **Development Environment:** Docker and VS Code.
- **Testing:** Pytest, interacting with the PostgREST API and directly with the database.

### 3.2. Knowledge Base

All technical knowledge, code examples, and implementation patterns are documented in the separate `KNOWLEDGE_BASE.md` file. This includes:

- PostgREST RPC/Function call patterns
- Password hashing with pgcrypto
- Task management functions
- Frontend serving from PostgreSQL
- pg_cron scheduling
- Testing patterns
- Security considerations

## 4. Implementation Roadmap

This roadmap breaks down the project into testable, sequential features.

### Phase 1: Setup and Core Schema
- [x] **1.1:** Initialize `docker-compose.yml` to set up the PostgreSQL container with PostgREST.
- [x] **1.2:** Create the initial database schema in `init.sql` for `users`, `tasks`, and `task_assignments`.
- [x] **1.3:** Set up `conftest.py` and initial test files (`test_schema.py`, `test_api.py`).
- [x] **1.4:** Write a test to confirm the database and PostgREST are accessible.
- [x] **1.5:** **(Verify)** Run tests and confirm the database and PostgREST are accessible.

### Phase 2: User Authentication (Simple Password)
- [x] **2.1:** **(Test)** Write tests for user registration and login endpoints.
- [x] **2.2:** **(Implement)** Create the `register_user` and `login` functions in PostgreSQL using `pgcrypto` for password hashing.
- [x] **2.3:** **(Verify)** Run tests and confirm users can be created and can authenticate successfully.

### Phase 3: Task & Turn Management
- [ ] **3.1:** **(Test)** Write tests for creating tasks and assigning them.
- [ ] **3.2:** **(Implement)** Create functions to manage tasks and implement the initial staggered assignment logic.
- [ ] **3.3:** **(Test)** Write tests for the turn rotation logic.
- [ ] **3.4:** **(Implement)** Create a PostgreSQL function, scheduled with `pg_cron`, to handle automatic turn rotation.
- [ ] **3.5:** **(Verify)** Run all tests to confirm task and turn management works as expected.

### Phase 4: Task Completion & Review
- [ ] **4.1:** **(Test)** Write a test for a user marking their own task as complete.
- [ ] **4.2:** **(Implement)** Create the `complete_task` function, ensuring it checks for ownership.
- [ ] **4.3:** **(Test)** Write tests for the review system (rejecting a task).
- [ ] **4.4:** **(Implement)** Create the `reject_task` function.
- [ ] **4.5:** **(Verify)** Run all tests to confirm the completion and review workflow.

### Phase 5: Frontend
- [ ] **5.1:** **(Implement)** Create a mechanism to store and serve a basic `index.html` from the database.
- [ ] **5.2:** **(Implement)** Develop the UI to display tasks and allow interaction with the API.

### Phase 6: Advanced Authentication (JWT)
- [ ] **6.1:** **(Test)** Write tests for JWT-based authentication using `pg_jwt`.
- [ ] **6.2:** **(Implement)** Create JWT token generation and validation functions.
- [ ] **6.3:** **(Implement)** Update login function to return JWT tokens.
- [ ] **6.4:** **(Verify)** Run tests and confirm JWT authentication works correctly.