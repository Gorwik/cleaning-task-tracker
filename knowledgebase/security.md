# Security: Input Validation, RBAC, and Best Practices

## Input Validation
- Always validate inputs in SQL functions
- Example:
```sql
CREATE OR REPLACE FUNCTION api.safe_function(p_input TEXT)
RETURNS JSON AS $$
BEGIN
  IF p_input IS NULL OR LENGTH(TRIM(p_input)) = 0 THEN
    PERFORM set_config('response.status', '400', true);
    RETURN json_build_object('error', 'Input cannot be empty');
  END IF;
  -- Continue with function logic...
END;
$$ LANGUAGE plpgsql;
```

## SQL Injection Prevention
- Use parameterized queries (PostgreSQL functions handle this automatically)
- Validate all inputs
- Use proper escaping for dynamic SQL (if needed)
- Limit function permissions with `SECURITY DEFINER` when appropriate

## Role-Based Access Control (RBAC)
- Define clear role hierarchy
- Grant only necessary privileges to each role
- Use schema-level and object-level permissions

## Function Security
- Use `SECURITY DEFINER` for functions that need elevated privileges
- Limit function access with explicit grants

## Monitoring & Auditing
- Regularly audit roles, permissions, and ownership
- Use monitoring scripts to check for issues

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 