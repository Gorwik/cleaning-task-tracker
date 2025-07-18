# Testing: Patterns, Best Practices, and Troubleshooting

## Overview
Testing is critical for ensuring correctness, security, and maintainability. This project uses Pytest for API and database tests, and includes RLS and migration tests.

## Test Types
- **Schema tests:** Validate table structure, constraints, and relationships
- **API tests:** Test all endpoints, including edge cases and error handling
- **RLS tests:** Ensure policies enforce correct access
- **Migration tests:** Verify migrations apply cleanly and preserve data
- **CI/CD tests:** Run all tests automatically on each commit

## Example: Pytest API Test
```python
import requests

def test_user_registration():
    response = requests.post('http://localhost:3000/rpc/register_user', json={
        'p_username': 'testuser',
        'p_password': 'password123'
    })
    assert response.status_code == 201
    assert response.json()['username'] == 'testuser'
```

## Best Practices
- Write tests for both success and failure scenarios
- Cover edge cases and boundary conditions
- Test both API endpoints and direct database functions
- Run tests in CI/CD before every deployment

## Troubleshooting
- Use fixtures to ensure API is up before running tests
- Check for missing schema, role, or endpoint errors
- Use `docker logs` and `psql` for debugging

## Navigation
- [Knowledge Base Home](./README.md)
- [Project README](../README.md) 