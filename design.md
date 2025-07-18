# System Design & Architecture

## 1. Tech Stack & Knowledge Base

- **Backend:** PostgreSQL
- **API:** PostgREST
- **Authentication:** `pg_jwt` (JWT, planned), `pgcrypto` (passwords)
- **Scheduling:** `pg_cron`
- **Frontend:** Static HTML/CSS/JS (bucket-hosted in production)
- **Dev Environment:** Docker, VS Code
- **Testing:** Pytest (API & DB)
- **Knowledge Base:** See [Knowledge Base](./knowledgebase/) for all technical patterns, code, and security notes.

## 2. Architecture Overview

- Multi-schema, role-based PostgreSQL backend
- API exposed via PostgREST (RESTful, schema-driven)
- Frontend decoupled, served as static assets
- RLS (Row Level Security) for fine-grained access control
- CI/CD pipeline for automated testing and deployment

## 3. Design Guidelines

- Use dedicated schemas for data, functions, and API views
- All objects owned by `app_owner` for production
- API roles: `api_user`, `api_anon`, `api_authenticated` with least-privilege grants
- All business logic in SQL functions, exposed via PostgREST RPC
- RLS policies must be explicit and testable
- All changes must be test-driven and documented

## 4. Rationale

- Schema and role separation ensures security and maintainability
- Test-driven workflow prevents regressions and ensures requirements are met
- Decoupled frontend allows flexible deployment and scaling

## 5. Security Considerations

- **Development:** Basic role separation, simple RLS, direct DB access for debugging
- **Production:** Multi-layer role hierarchy, schema-based access, comprehensive RLS, automated audits, encrypted connections

## 6. Development vs Production Workflow

**Development:**
- Rapid iteration, manual changes, direct DB access, Docker for isolation

**Production:**
- Zero-downtime (blue-green), automated migrations, monitoring, disaster recovery

## 7. See Also
- [Project Requirements](./requirements.md)
- [Project TODO Checklist](./todo_check_list.md)
- [Knowledge Base](./knowledgebase/) 