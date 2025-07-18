# Project Requirements

## 1. Project Overview

This application digitalizes and streamlines cleaning task tracking among roommates, using PostgreSQL as the backend for task assignments, completion, review, and notifications.

**Frontend Note:**
- In production, the frontend (index.html, CSS, JS, images, etc.) is served as static assets from a bucket (e.g., AWS S3, Google Cloud Storage), NOT via PostgREST or the database.
- During development, open `index.html` directly in your browser for manual testing.

## 2. Core Features & Requirements

- **Authentication:** Users log in with username and password; can only mark their own assigned tasks as complete.
- **Task Management:** Users mark tasks as done; all users see all task statuses.
- **Review System:** Completed tasks can be rejected, requiring redo by the same user until approved (no reassignment after rejection).
- **Turn & Schedule Management:** Automated, sequential task rotation; staggered start; handles user unavailability.
- **Notifications:** System supports SMS/email notifications (details TBD).

## 3. Roadmap

- Stage 1: Development Foundation
- Stage 2: Production Preparation
- Stage 3: Post-Production Feature Expansion
- Stage 4: Production Deployment

## 4. Acceptance Criteria

- All users can register, log in, and see their assignments
- Only assigned users can mark tasks as complete
- Completed tasks can be reviewed and rejected, requiring redo
- Task rotation is automated and fair
- All API endpoints and UI features are covered by tests
- System is deployable with a single initialization script

## 5. Workflow & Contribution Guidelines

- All development follows a strict test-driven, phased workflow with granular sub-tasks (Write Test, Write Executable, Verify) and explicit user verification gates.
- All contributors must keep requirements, design, and checklist files up to date as features are added or changed.
- See [Design & Architecture](./design.md) and [Project TODO Checklist](./todo_check_list.md) for technical and implementation details.
- See [Knowledge Base](./knowledgebase/) for all technical patterns, code, and security notes. 