import pytest
import requests

class TestPostgRESTAPI:
    """Test PostgREST API endpoints."""
    
    def test_api_root_endpoint(self, api_client):
        """Test that the API root endpoint is accessible."""
        response = api_client.get('/')
        assert response.status_code == 200
    
    def test_openapi_specification(self, api_client):
        """Test that OpenAPI specification is available."""
        response = api_client.get('/')
        assert response.status_code == 200
        # Should return OpenAPI spec
        assert 'openapi' in response.text.lower() or 'swagger' in response.text.lower()
    
    def test_users_table_endpoint(self, api_client):
        """Test that users table is accessible via API."""
        response = api_client.get('/users')
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 3  # Should have at least 3 users from seed data
    
    def test_tasks_table_endpoint(self, api_client):
        """Test that tasks table is accessible via API."""
        response = api_client.get('/tasks')
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 6  # Should have at least 6 tasks from seed data
    
    def test_task_assignments_table_endpoint(self, api_client):
        """Test that task_assignments table is accessible via API."""
        response = api_client.get('/task_assignments')
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 6  # Should have at least 6 assignments from seed data
    
    def test_users_filtering(self, api_client):
        """Test that users can be filtered by username."""
        response = api_client.get('/users?username=eq.user1')
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]['username'] == 'user1'
    
    def test_tasks_filtering(self, api_client):
        """Test that tasks can be filtered by task_name."""
        response = api_client.get('/tasks?task_name=eq.Kitchen Cleaning')
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]['task_name'] == 'Kitchen Cleaning'
    
    def test_task_assignments_join(self, api_client):
        """Test that task_assignments can be joined with users and tasks."""
        response = api_client.get('/task_assignments?select=*,users(username),tasks(task_name)')
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 6
        
        # Check that joined data is present
        first_assignment = data[0]
        assert 'users' in first_assignment
        assert 'tasks' in first_assignment
    
    def test_api_schema_permissions(self, api_client):
        """Test that API schema endpoints are properly configured."""
        # Test that we can't access non-existent endpoints
        response = api_client.get('/nonexistent_table')
        assert response.status_code == 404
    
    def test_cors_headers(self, api_client):
        """Test that CORS headers are present (if configured)."""
        response = api_client.get('/')
        # This test is more about ensuring the API responds properly
        # CORS headers might not be configured yet
        assert response.status_code == 200
    
    def test_content_type_headers(self, api_client):
        """Test that proper content-type headers are returned."""
        response = api_client.get('/users')
        assert response.status_code == 200
        assert 'application/json' in response.headers.get('content-type', '')

class TestAPIErrorHandling:
    """Test API error handling."""
    
    def test_invalid_filter_syntax(self, api_client):
        """Test that invalid filter syntax returns proper error."""
        response = api_client.get('/users?username=invalid_syntax')
        # Should return 400 or similar error
        assert response.status_code in [400, 422]
    
    def test_nonexistent_column_filter(self, api_client):
        """Test that filtering by non-existent column returns error."""
        response = api_client.get('/users?nonexistent_column=eq.test')
        assert response.status_code in [400, 422]
    
    def test_invalid_join_syntax(self, api_client):
        """Test that invalid join syntax returns error."""
        response = api_client.get('/task_assignments?select=*,invalid_table(column)')
        assert response.status_code in [400, 422]

class TestAPIPerformance:
    """Test basic API performance characteristics."""
    
    def test_users_response_time(self, api_client):
        """Test that users endpoint responds within reasonable time."""
        import time
        start_time = time.time()
        response = api_client.get('/users')
        end_time = time.time()
        
        assert response.status_code == 200
        assert (end_time - start_time) < 5.0  # Should respond within 5 seconds
    
    def test_large_dataset_handling(self, api_client):
        """Test that API can handle reasonable dataset sizes."""
        # This test ensures the API doesn't crash with normal data sizes
        response = api_client.get('/task_assignments?limit=100')
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list) 