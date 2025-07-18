# Project TODO Checklist

*This file is the canonical project checklist. See [README.md](./README.md) for project overview and navigation.*

## Stage 1: Development Foundation

### Completed Features (with technical sub-tasks)
- [x] PostgreSQL + PostgREST Docker setup
    - [x] Write test: `tests/test_schema.py` - test DB and API accessibility
    - [x] Write executable: `docker-compose.yml`, `init.sql`, `api_setup.sql`
    - [x] Verify: `poetry run pytest`, check containers are running
- [x] Initial schema: `users`, `tasks`, `task_assignments`
    - [x] Write test: `tests/test_schema.py` - test table creation and constraints
    - [x] Write executable: `init.sql`
    - [x] Verify: `poetry run pytest`, inspect DB schema
- [x] Pytest setup: `conftest.py`, `test_schema.py`, `test_api.py`
    - [x] Write test: Create initial test files and sample test functions
    - [x] Write executable: `tests/conftest.py`, `tests/test_schema.py`, `tests/test_api.py`
    - [x] Verify: `poetry run pytest` runs without errors
- [x] User registration & login (password hashed with pgcrypto)
    - [x] Write test: `tests/test_api.py::test_user_registration`, `test_user_login`
    - [x] Write executable: `init.sql`/`api_setup.sql` - `register_user`, `login` functions
    - [x] Verify: `poetry run pytest`, manual test via frontend
- [x] Task creation, assignment, and staggered initial assignment
    - [x] Write test: `tests/test_api.py::test_task_creation`, `test_task_assignment`
    - [x] Write executable: `init.sql`/`api_setup.sql` - task/assignment logic
    - [x] Verify: `poetry run pytest`, check DB state
- [x] Turn rotation logic (with `pg_cron`)
    - [x] Write test: `tests/test_api.py::test_turn_rotation`
    - [x] Write executable: `init.sql`/`api_setup.sql` - turn rotation function, `pg_cron` config
    - [x] Verify: `poetry run pytest`, check scheduled jobs
- [x] Task completion and review (approve/reject)
    - [x] Write test: `tests/test_api.py::test_task_completion`, `test_task_review_rejection`
    - [x] Write executable: `init.sql`/`api_setup.sql` - `complete_task`, `review_task` logic
    - [x] Verify: `poetry run pytest`, manual test via frontend
- [x] Frontend aligned to backend API
    - [x] Write test: `tests/test_api.py::test_frontend_api_alignment` (mock/test API calls)
    - [x] Write executable: `index.html`, JS code for API calls
    - [x] Verify: Open `index.html`, check dashboard loads data correctly
- [x] Modern, responsive UI for task management
    - [x] Write test: Manual UI/UX review, optional automated UI test
    - [x] Write executable: `index.html`, CSS, JS
    - [x] Verify: Open in browser, check responsiveness and usability
- [x] All tests for above features
    - [x] Write test: Ensure all relevant test cases are covered in `tests/`
    - [x] Write executable: Add missing tests as needed
    - [x] Verify: `poetry run pytest` (all tests pass)

### Task Review Rejection Flow (Integrated)
- [x] Rejected tasks reappear in "Current Task Assignments" for the original user, marked as needing redo
    - [x] Write test: `tests/test_api.py::test_rejected_task_reappears`
    - [x] Write executable: Backend logic for `is_approved = false`, frontend marker
    - [x] Verify: `poetry run pytest`, check UI
- [x] Rejected tasks are removed from completion/history list
    - [x] Write test: `tests/test_api.py::test_rejected_task_not_in_history`
    - [x] Write executable: Backend view/query, frontend filter
    - [x] Verify: `poetry run pytest`, check UI
- [x] `is_approved` field: `null` (pending), `true` (approved), `false` (rejected)
    - [x] Write test: `tests/test_api.py::test_is_approved_field_logic`
    - [x] Write executable: DB schema, logic in SQL
    - [x] Verify: `poetry run pytest`, DB inspection
- [x] Frontend visually distinguishes rejected tasks in assignments
    - [x] Write test: Manual UI/UX review
    - [x] Write executable: JS/CSS for rejected marker
    - [x] Verify: Open in browser, check marker
- [x] Tests verify rejected tasks can be redone, are not shown in history, and workflow is robust
    - [x] Write test: `tests/test_api.py::test_rejected_task_redo_workflow`
    - [x] Write executable: Ensure all edge cases are covered
    - [x] Verify: `poetry run pytest`, manual test

#### Final Workflow Summary
- Tasks can be completed and reviewed. If rejected, they are marked with `is_approved = false` and remain assigned to the same user.
- Rejected tasks are shown in "Current Task Assignments" with a clear marker ("Rejected: Please redo").
- Rejected tasks are not shown in "Recent Completion History".
- When redone, marking as complete resets `is_approved` to `null` and updates `completed_at`.
- All logic uses only `is_approved` and `completed_at`—no extra fields needed.

### Frontend Alignment to Backend API (Plan)
1. Inventory backend endpoints (from `api_setup.sql`, `init.sql`)
2. Map frontend data needs to backend endpoints
3. Update API calls in frontend to match backend
4. Test and validate dashboard data loading

---

## Stage 2: Production Preparation

**See [`PRODUCTION_GUIDE.md`](PRODUCTION_GUIDE.md) for full details and scripts.**

### 🟦 Detailed Checklist: Production Schema, Role, and Initialization Readiness
- [x] **Preparation & Planning**
    - [x] Inventory all current tables, functions, and views needed for production
    - [x] Identify all schemas, roles, and privileges required for production
    - _Inventory and planning for schema/role creation completed and approved by user._
- [ ] **Schema & Role Initialization (Tabula Rasa)**
    - [ ] Write a single, production-ready SQL script (`production_init.sql`) that:
        - [ ] Creates all required roles (`app_owner`, `api_user`, `api_anon`, `api_authenticated`)
        - [ ] Creates all schemas (`app_data`, `app_functions`, `app_frontend`, `api`) owned by `app_owner`
        - [ ] Creates all tables, views, and functions in their correct schemas
        - [ ] Applies all privileges and ownerships as required
        - [ ] Enables and configures RLS on all tables
        - [ ] Seeds initial data if needed
    - [ ] Test the script by initializing a fresh database and verifying all objects
- [ ] **Ownership & Permissions**
    - [ ] Ensure all objects are owned by `app_owner`
    - [ ] Grant only the intended privileges to each role
    - [ ] Revoke all unnecessary privileges from `public`
- [ ] **Row Level Security (RLS)**
    - [ ] Enable RLS on all tables in `app_data`
    - [ ] Write and test strict RLS policies for each table (not just `USING (true)`)
    - [ ] Use session variables/JWT claims for user scoping in policies
- [ ] **Testing**
    - [ ] Write tests to verify:
        - [ ] All objects are in the correct schema
        - [ ] All objects are owned by `app_owner`
        - [ ] All roles have only the intended privileges
        - [ ] RLS policies enforce correct access
        - [ ] All API endpoints work as expected
    - [ ] Run full regression test suite after initialization
- [ ] **Backup, Restore, and Rollback**
    - [ ] Backup the database after initialization
    - [ ] Test restore and rollback procedures
    - [ ] Document the process for disaster recovery
- [ ] **Documentation**
    - [ ] Update all documentation to reference new schema/object names
    - [ ] Document the initialization process and any manual steps required
- [ ] **Production Dry Run**
    - [ ] Perform a dry run of the initialization and deployment on a staging environment
    - [ ] Validate all application functionality post-initialization
    - [ ] Review logs and monitoring for errors or permission issues

### Checklist (with technical sub-tasks)
- [ ] Implement `app_owner` role and schema separation
    - [ ] Write test: Add migration/ownership tests (e.g., check role/schema in DB)
    - [ ] Write executable: `production_init.sql`, update Docker config
    - [ ] Verify: Run DB queries, check schema/role ownership
- [ ] Create migration scripts for ownership management
    - [ ] Write test: Migration test (apply/revert, check DB state)
    - [ ] Write executable: `migrations/001_setup_production_ownership.sql`
    - [ ] Verify: Apply migration, check DB
- [ ] Set up monitoring and automated fixes
    - [ ] Write test: Monitoring script test (simulate failure, check alert)
    - [ ] Write executable: `monitor.sh`
    - [ ] Verify: Run script, check output
- [ ] Implement blue-green deployment strategy
    - [ ] Write test: Deployment test (simulate switch, check zero downtime)
    - [ ] Write executable: Update Docker, deployment scripts
    - [ ] Verify: Deploy, check service availability
- [ ] Prepare automated CI/CD pipeline
    - [ ] Write test: CI/CD pipeline test (simulate build/deploy)
    - [ ] Write executable: CI/CD config/scripts
    - [ ] Verify: Run pipeline, check logs
- [ ] Comprehensive testing suite for production
    - [ ] Write test: Add/expand tests for production scenarios
    - [ ] Write executable: Update/add tests as needed
    - [ ] Verify: Run all tests
- [ ] Monitoring and alerting
    - [ ] Write test: Simulate alert condition
    - [ ] Write executable: Monitoring/alerting config
    - [ ] Verify: Trigger alert, check notification
- [ ] Backup and disaster recovery procedures
    - [ ] Write test: Simulate backup/restore
    - [ ] Write executable: Backup scripts/config
    - [ ] Verify: Perform backup/restore, check data integrity

---

### 🟦 Detailed Checklist: Row Level Security (RLS) Policy Design
*Rationale: RLS is critical for data security and multi-tenancy. Mistakes can lead to data leaks or broken functionality. This checklist ensures robust, testable policies.*
- [ ] **Preparation**
    - [ ] List all tables requiring RLS
    - [ ] Identify all access patterns (read, write, update, delete) for each table
    - [ ] Define user roles and session variables/JWT claims needed for policy logic
- [ ] **Policy Design**
    - [ ] Write `SELECT` policies for each table (who can read which rows?)
    - [ ] Write `INSERT` policies (who can create which rows? Use `WITH CHECK` as needed)
    - [ ] Write `UPDATE` policies (who can update which rows? Use `USING` and `WITH CHECK`)
    - [ ] Write `DELETE` policies (who can delete which rows?)
    - [ ] Use session variables/JWT claims for user scoping (e.g., `current_setting('jwt.claims.user_id', true)`)
    - [ ] Add policies for special cases (e.g., admin, soft delete, multi-tenancy)
- [ ] **Testing**
    - [ ] Write tests for allowed and forbidden access for each policy (pytest or PgTap)
    - [ ] Test edge cases (e.g., missing claims, invalid roles)
    - [ ] Run full regression suite after policy changes
- [ ] **Review**
    - [ ] Peer review all policies for logic errors or overly broad access
    - [ ] Document policy rationale in code or docs

---

### 🟦 Detailed Checklist: JWT Authentication (Stage 3/4)
*Rationale: JWT is the foundation for stateless, secure authentication and user scoping. This checklist ensures robust, standards-compliant implementation.*
- [ ] **Preparation**
    - [ ] Choose and install JWT extension (e.g., `pg_jwt`)
    - [ ] Define JWT claims needed for RLS and app logic (e.g., `user_id`, `role`, `exp`)
    - [ ] Set up JWT secret management (env vars, secrets manager)
- [ ] **Implementation**
    - [ ] Write SQL function to issue JWTs on login (returns token with correct claims)
    - [ ] Update login endpoint to return JWT
    - [ ] Configure PostgREST to accept and validate JWTs
    - [ ] Use claims in RLS policies and functions
- [ ] **Testing**
    - [ ] Write tests for token issuance (valid/invalid credentials)
    - [ ] Write tests for token validation (expired, tampered, missing claims)
    - [ ] Test RLS and API endpoints with/without valid JWTs
- [ ] **Security**
    - [ ] Rotate JWT secrets regularly
    - [ ] Set reasonable token expiry (`exp` claim)
    - [ ] Never store sensitive data in JWT payload
    - [ ] Document JWT structure and usage

---

### 🟦 Detailed Checklist: CI/CD Pipeline (Stage 4)
*Rationale: Automated CI/CD ensures repeatable, reliable deployments and reduces human error. This checklist covers best practices for database-driven apps.*
- [ ] **Preparation**
    - [ ] Choose CI/CD platform (GitHub Actions, GitLab CI, etc.)
    - [ ] Store secrets securely (env vars, secrets manager)
- [ ] **Pipeline Design**
    - [ ] Lint and static check all code (SQL, Python, JS)
    - [ ] Run all tests (unit, integration, migration, RLS, API)
    - [ ] Build and push Docker images (if used)
    - [ ] Apply database migrations in a safe, idempotent way
    - [ ] Deploy application and run post-deploy health checks
    - [ ] Rollback on failure
- [ ] **Testing**
    - [ ] Test pipeline on staging/fork before production use
    - [ ] Simulate failure scenarios (migration error, test failure, deploy error)
- [ ] **Monitoring**
    - [ ] Notify team on pipeline failures or warnings
    - [ ] Archive build/test logs for audit
    - [ ] Document pipeline steps and troubleshooting

---

### 🟦 Detailed Checklist: Backup and Disaster Recovery (Stage 4)
*Rationale: Backups and tested recovery procedures are essential for business continuity. This checklist ensures you can recover from data loss or migration errors.*
- [ ] **Backup Strategy**
    - [ ] Schedule regular automated database backups (full and incremental)
    - [ ] Store backups securely (offsite, encrypted)
    - [ ] Document backup retention policy
- [ ] **Restore Testing**
    - [ ] Regularly test restore process on a staging environment
    - [ ] Validate data integrity and application functionality after restore
    - [ ] Document restore steps and required credentials
- [ ] **Disaster Recovery Plan**
    - [ ] Define RTO (Recovery Time Objective) and RPO (Recovery Point Objective)
    - [ ] Document step-by-step recovery procedures
    - [ ] Assign roles and responsibilities for recovery
    - [ ] Simulate disaster scenarios and review lessons learned

---

## Stage 3: Post-Production Feature Expansion

Features to be implemented after first production deployment:

### Frontend Expansion
- [ ] Create DB schema for storing frontend assets (HTML, CSS, JS) with content-type management
    - [ ] Write test: DB schema test (table/column existence)
    - [ ] Write executable: SQL for schema/assets
    - [ ] Verify: Query DB, check asset storage
- [ ] PostgreSQL functions to serve HTML, CSS, JS with correct headers/caching
    - [ ] Write test: API test for content serving
    - [ ] Write executable: SQL functions for serving assets
    - [ ] Verify: Fetch assets via API, check headers/content
- [ ] Tests for frontend serving functions
    - [ ] Write test: Add/expand tests for asset serving
    - [ ] Write executable: Add/expand test cases
    - [ ] Verify: Run tests
- [ ] Full frontend-to-backend integration tests
    - [ ] Write test: Integration test (end-to-end)
    - [ ] Write executable: Integration test scripts
    - [ ] Verify: Run integration tests

### Advanced Authentication (JWT)
- [ ] Tests for JWT-based authentication (`pg_jwt`)
    - [ ] Write test: Add JWT auth tests (login, token validation)
    - [ ] Write executable: Test cases in `tests/test_api.py`
    - [ ] Verify: Run tests
- [ ] JWT token generation and validation functions
    - [ ] Write test: Unit test for token generation/validation
    - [ ] Write executable: SQL functions for JWT
    - [ ] Verify: Run tests, check token validity
- [ ] Update login to return JWT tokens
    - [ ] Write test: API test for login response
    - [ ] Write executable: Update login function
    - [ ] Verify: Login, check token in response
- [ ] End-to-end JWT authentication tests
    - [ ] Write test: End-to-end auth test
    - [ ] Write executable: Integration test
    - [ ] Verify: Run test, check access control

---

## Stage 4: Production Deployment

- [ ] Deploy using automated CI/CD pipeline
    - [ ] Write test: Simulate deployment, check for errors
    - [ ] Write executable: Run pipeline/deploy scripts
    - [ ] Verify: Check deployment status, logs
- [ ] Run comprehensive test suite
    - [ ] Write test: Ensure all tests are included
    - [ ] Write executable: Add missing tests
    - [ ] Verify: Run all tests
- [ ] Enable monitoring and alerting
    - [ ] Write test: Simulate alert, check notification
    - [ ] Write executable: Monitoring/alerting config
    - [ ] Verify: Trigger alert, check system
- [ ] Set up backup and disaster recovery
    - [ ] Write test: Simulate backup/restore
    - [ ] Write executable: Backup/restore scripts
    - [ ] Verify: Perform backup/restore, check data

---

## Security Considerations

- **Development:** Basic role separation, simple RLS, direct DB access for debugging
- **Production:** Multi-layer role hierarchy, schema-based access, comprehensive RLS, automated audits, encrypted connections

---

## Development vs Production Workflow

**Development:**
- Rapid iteration, manual changes, direct DB access, Docker for isolation

**Production:**
- Zero-downtime (blue-green), automated migrations, monitoring, disaster recovery 