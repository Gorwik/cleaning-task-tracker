# Cleaning Task Tracker

## 1. Project Overview

This application aims to digitalize and streamline the process of tracking cleaning tasks among roommates. Leveraging PostgreSQL as the primary backend, it will manage task assignments, completion tracking, review processes, and notifications.

**Frontend Note:**
- In production, the frontend (index.html, CSS, JS, images, etc.) will be served as static assets from a bucket (e.g., AWS S3, Google Cloud Storage, or similar static hosting), NOT via PostgREST or the database.
- During development, you can open `index.html` directly in your browser for manual testing.

## 2. Core Features & Requirements

### User & Authentication
- **Authentication:** Users must log in with a username and password.
- **Authorization:** Users can only mark their own assigned tasks as complete.

### Task Management
- **Task Completion:** Users can mark their assigned tasks as "done."
- **Progress Visibility:** All users can see the status of all tasks.
- **Review System:** A review process allows users to "reject" a completed task, marking it as needing correction. If a task is rejected, the same user must redo the task until it is approved—no reassignment occurs after rejection. This process is similar to a GitHub review, but the responsibility remains with the original assignee until approval.

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
- **Frontend:** Static HTML, CSS, and JavaScript served from a static bucket (S3, GCS, etc.) in production. For development, open `index.html` directly in your browser.
- **Development Environment:** Docker and VS Code.
- **Testing:** Pytest, interacting with the PostgREST API and directly with the database.

### 3.2. Knowledge Base

All technical knowledge, code examples, and implementation patterns are documented in the separate `KNOWLEDGE_BASE.md` file. This includes:

- PostgREST RPC/Function call patterns
- Password hashing with pgcrypto
- Task management functions
- pg_cron scheduling
- Testing patterns
- Security considerations
- **Production-ready database ownership management**

## 4. Production-Ready Database Ownership Management

### 4.1. Current Development vs Production Requirements

**Development Stage:**
- Database rebuilds are acceptable for rapid iteration
- Manual ownership changes are manageable
- Simple role structure suffices

**Production Stage:**
- Zero-downtime deployments required
- Automated schema migrations
- Proper role separation and security
- No manual database interventions

### 4.2. Production Solutions

#### **Solution 1: Proper Role Hierarchy (Recommended)**
- Create dedicated `app_owner` role for all application objects
- Use schema-based separation (`app_data`, `app_functions`, `app_frontend`)
- Implement proper RBAC with clear permission boundaries
- Enable comprehensive monitoring and automated ownership fixes

#### **Solution 2: Migration-Based Management**
- Version-controlled ownership changes
- Automated CI/CD integration
- Rollback capability
- Production-safe deployment scripts

#### **Solution 3: Blue-Green Deployment**
- Zero-downtime deployments
- Automated backup and restore procedures
- Comprehensive health checks
- Rollback mechanisms

### 4.3. Implementation Timeline

**Phase 1: Development Foundation (Current)**
- [x] Basic three-role system (`api_user`, `api_anon`, `api_authenticated`)
- [x] Core functionality working
- [x] Frontend serving capabilities

**Phase 2: Production Preparation**
- [ ] Implement `app_owner` role and schema separation
- [ ] Create migration scripts for ownership management
- [ ] Set up monitoring and automated fixes
- [ ] Implement blue-green deployment strategy

**Phase 3: Production Deployment**
- [ ] Automated CI/CD pipeline
- [ ] Comprehensive testing suite
- [ ] Monitoring and alerting
- [ ] Backup and disaster recovery procedures

## 5. Implementation Roadmap

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
- [x] **3.1:** **(Test)** Write tests for creating tasks and assigning them.
- [x] **3.2:** **(Implement)** Create functions to manage tasks and implement the initial staggered assignment logic.
- [x] **3.3:** **(Test)** Write tests for the turn rotation logic.
- [x] **3.4:** **(Implement)** Create a PostgreSQL function, scheduled with `pg_cron`, to handle automatic turn rotation.
- [x] **3.5:** **(Verify)** Run all tests to confirm task and turn management works as expected.

### Phase 4: Task Completion & Review
- [x] **4.1:** **(Test)** Write a test for a user marking their own task as complete.
- [x] **4.2:** **(Implement)** Create the `complete_task` function, ensuring it checks for ownership.
- [x] **4.3:** **(Test)** Write tests for the review system (rejecting a task).
- [x] **4.4:** **(Implement)** Create the `reject_task` function.
- [x] **4.5:** **(Verify)** Run all tests to confirm the completion and review workflow.

### Phase 5: Frontend
- [x] **5.1:** **(Research)** Research PostgREST capabilities for serving frontend content and best practices for storing HTML/CSS/JS in PostgreSQL.
- [ ] **5.2:** **(Implement)** Create database schema for storing frontend assets (HTML, CSS, JS) with proper content-type management.
- [ ] **5.3:** **(Implement)** Create PostgreSQL functions to serve different content types (HTML, CSS, JS) with appropriate headers and caching.
- [x] **5.4:** **(Implement)** Develop a modern, responsive UI for task management with authentication, task display, and interaction capabilities.
- [ ] **5.5:** **(Test)** Write tests for frontend serving functions and verify the complete user interface works correctly.
- [ ] **5.6:** **(Verify)** Test the complete frontend-to-backend integration and ensure all features work seamlessly.

### Phase 6: Advanced Authentication (JWT)
- [ ] **6.1:** **(Test)** Write tests for JWT-based authentication using `pg_jwt`.
- [ ] **6.2:** **(Implement)** Create JWT token generation and validation functions.
- [ ] **6.3:** **(Implement)** Update login function to return JWT tokens.
- [ ] **6.4:** **(Verify)** Run tests and confirm JWT authentication works correctly.

### Phase 7: Production Readiness
- [ ] **7.1:** **(Implement)** Create `app_owner` role and schema separation strategy.
- [ ] **7.2:** **(Implement)** Develop migration scripts for ownership management.
- [ ] **7.3:** **(Implement)** Set up monitoring and automated ownership fixes.
- [ ] **7.4:** **(Implement)** Create blue-green deployment strategy.
- [ ] **7.5:** **(Test)** Comprehensive production testing and validation.
- [ ] **7.6:** **(Verify)** Production deployment with zero-downtime capabilities.

## Task Review Rejection Flow: Requirements Checklist

- [x] When a reviewer rejects a completed task, it is immediately shown again in the "Current Task Assignments" for the original user, marked as needing to be redone.
- [x] The task is removed from the completed/history list if rejected.
- [x] The task is annotated using the `is_approved` field: `null` (pending), `true` (approved), `false` (rejected).
- [x] When a task is created or assigned normally, `is_approved` is `null`.
- [x] When a task is rejected during review, `is_approved` is set to `false` and the task remains assigned to the same user.
- [x] The frontend visually distinguishes tasks with `is_approved === false` (e.g., badge, color, or icon) to indicate they are being redone after rejection, but only in Current Task Assignments.
- [x] No change to logic for primary tasks (`is_approved === null`).
- [x] Tests verify that rejected tasks can be redone, are not shown in history, and the workflow is robust.

### Final Workflow Summary
- Tasks can be completed and reviewed. If rejected, they are marked with `is_approved = false` and remain assigned to the same user.
- Rejected tasks are shown in the "Current Task Assignments" section with a clear marker ("Rejected: Please redo").
- Rejected tasks are not shown in the "Recent Completion History".
- When the user redoes the task, they can mark it as complete again, which resets `is_approved` to `null` and updates `completed_at`.
- The review process can then repeat as needed until the task is approved.
- All logic is handled using the `is_approved` field and `completed_at` timestamp—no extra fields are needed.

## Phase 1.1: Frontend Alignment to Backend API (New Plan)

### Business Requirements
- The frontend (index.html) must use only the endpoints, views, and functions that are actually present and exposed by the backend as defined in `api_setup.sql` and `init.sql`.
- All API calls in index.html must match the actual PostgREST-exposed endpoints (including correct paths, methods, and parameters).
- The frontend must handle the data shape returned by these endpoints (e.g., field names, object structure).

### Implementation Roadmap
1. **Inventory Backend Endpoints**
   - List all views and functions exposed by the backend (from `api_setup.sql` and `init.sql`).
2. **Map Frontend Data Needs**
   - For each dashboard section (assignments, reviews, history), determine which backend endpoint provides the required data.
3. **Update API Calls in Frontend**
   - Adjust all fetch URLs, methods, and payloads in `index.html` to match backend endpoints.
   - Update JS code to handle the actual data structure returned by the backend.
4. **Test and Validate**
   - Ensure the dashboard loads data correctly and no longer throws errors.

## 6. Development vs Production Workflow

### Development Workflow
1. **Rapid Iteration:** Database rebuilds acceptable
2. **Manual Changes:** Ownership changes manageable
3. **Simple Testing:** Direct database access for debugging
4. **Local Development:** Docker containers for isolation

### Production Workflow
1. **Zero-Downtime:** Blue-green deployments
2. **Automated Migrations:** Version-controlled schema changes
3. **Comprehensive Monitoring:** Automated ownership and permission checks
4. **Disaster Recovery:** Automated backup and restore procedures

## 7. Security Considerations

### Development Security
- Basic role separation (`api_user`, `api_anon`, `api_authenticated`)
- Simple RLS policies for access control
- Direct database access for debugging

### Production Security
- Multi-layer role hierarchy with `app_owner`
- Schema-based access control
- Comprehensive RLS policies
- Automated security audits
- Encrypted connections and credentials