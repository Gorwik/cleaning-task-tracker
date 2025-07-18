# Row Level Security (RLS): Policy Design, Examples, and Troubleshooting

## Overview
Row Level Security (RLS) is used to enforce fine-grained access control in PostgreSQL, ensuring users can only access or modify rows they are authorized to see.

## Enabling RLS
```sql
ALTER TABLE app_data.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_data.task_assignments ENABLE ROW LEVEL SECURITY;
```

## Policy Design Checklist
- List all tables requiring RLS
- Identify all access patterns (read, write, update, delete)
- Define user roles and session variables/JWT claims needed for policy logic
- Write `SELECT`, `INSERT`, `UPDATE`, `DELETE` policies for each table
- Use session variables/JWT claims for user scoping (e.g., `current_setting('jwt.claims.user_id', true)`)
- Add policies for special cases (admin, soft delete, multi-tenancy)

## Example Policies
```sql
CREATE POLICY users_select_policy ON app_data.users
    FOR SELECT TO api_anon, api_authenticated
    USING (true);

CREATE POLICY users_insert_policy ON app_data.users
    FOR INSERT TO api_authenticated
    WITH CHECK (true);

CREATE POLICY tasks_user_policy ON app_data.tasks
    FOR ALL TO api_authenticated
    USING (assigned_user_id = current_setting('app.current_user_id')::int);
```

## Testing RLS
- Write tests for allowed and forbidden access for each policy
- Test edge cases (missing claims, invalid roles)
- Run full regression suite after policy changes

## Troubleshooting
- If all access is blocked, check for missing or overly strict policies
- Use `EXPLAIN` and `pg_row_security` to debug policy application

## Detailed Checklist: RLS Policy Design
*Rationale: RLS is critical for data security and multi-tenancy. Mistakes can lead to data leaks or broken functionality. This checklist ensures robust, testable policies.*
- [ ] Preparation: List tables, access patterns, roles, session variables
- [ ] Policy Design: Write SELECT/INSERT/UPDATE/DELETE policies, use claims, add special cases
- [ ] Testing: Write tests for allowed/forbidden access, edge cases, regression
- [ ] Review: Peer review, document rationale

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 