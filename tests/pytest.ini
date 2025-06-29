"""
Shared pytest configuration and fixtures for all tests
"""
import pytest
import requests
import time
import os
from typing import Dict, Any, List

# Configuration
BASE_URL = os.getenv("API_BASE_URL", "http://localhost:3001")
POSTGRES_CONFIG = {
    "host": os.getenv("POSTGRES_HOST", "localhost"),
    "port": int(os.getenv("POSTGRES_PORT", "5433")),
    "database": os.getenv("POSTGRES_DB", "cleaning_tracker_test"),
    "user": os.getenv("POSTGRES_USER", "cleaning_user"),
    "password": os.getenv("POSTGRES_PASSWORD", "cleaning_pass"),
}

HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json"
}

class APIClient:
    """Helper class for making API requests"""
    
    def __init__(self, base_url: str = BASE_URL):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
        self.auth_token = None
    
    def set_auth_token(self, token: str):
        """Set authentication token"""
        self.auth_token = token
        self.session.headers["Authorization"] = f"Bearer {token}"
    
    def clear_auth(self):
        """Clear authentication"""
        self.auth_token = None
        if "Authorization" in self.session.headers:
            del self.session.headers["Authorization"]
    
    def get(self, endpoint: str, params: Dict = None) -> requests.Response:
        """Make GET request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.get(url, params=params)
    
    def post(self, endpoint: str, data: Dict = None) -> requests.Response:
        """Make POST request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.post(url, json=data)
    
    def patch(self, endpoint: str, data: Dict = None) -> requests.Response:
        """Make PATCH request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.patch(url, json=data)
    
    def delete(self, endpoint: str) -> requests.Response:
        """Make DELETE request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.delete(url)
    
    def rpc(self, function_name: str, data: Dict = None) -> requests.Response:
        """Make RPC call to PostgreSQL function"""
        return self.post(f"/rpc/{function_name}", data)

@pytest.fixture(scope="session")
def wait_for_services():
    """Wait for all services to be ready"""
    api_client = APIClient()
    max_retries = 60
    retry_delay = 2
    
    print(f"Waiting for API at {BASE_URL}...")
    
    for attempt in range(max_retries):
        try:
            # Test API connection
            response = api_client.get("/")
            if response.status_code in [200, 404]:  # 404 is OK for root endpoint
                print("API is ready!")
                break
        except requests.exceptions.ConnectionError:
            if attempt < max_retries - 1:
                print(f"API not ready, retrying in {retry_delay}s... ({attempt + 1}/{max_retries})")
                time.sleep(retry_delay)
                continue
            raise Exception(f"API not ready after {max_retries * retry_delay} seconds")
    
    # Additional health check - try to fetch users
    try:
        response = api_client.get("/users?limit=1")
        if response.status_code != 200:
            raise Exception(f"API health check failed: {response.status_code}")
        print("API health check passed!")
    except Exception as e:
        raise Exception(f"API health check failed: {e}")
    
    return True

@pytest.fixture(scope="session")
def api_client(wait_for_services):
    """Create API client instance"""
    return APIClient()

@pytest.fixture(scope="session")
def test_users(api_client):
    """Get test users"""
    response = api_client.get("/users?username=like.testuser*")
    assert response.status_code == 200
    users = response.json()
    assert len(users) >= 2, f"Need at least 2 test users, found {len(users)}"
    return users

@pytest.fixture(scope="session")
def reviewer_users(api_client):
    """Get reviewer users"""
    response = api_client.get("/users?username=like.reviewer*")
    assert response.status_code == 200
    users = response.json()
    assert len(users) >= 1, f"Need at least 1 reviewer user, found {len(users)}"
    return users

@pytest.fixture(scope="session")
def test_tasks(api_client):
    """Get test tasks"""
    response = api_client.get("/tasks")
    assert response.status_code == 200
    tasks = response.json()
    assert len(tasks) >= 1, f"Need at least 1 task for testing, found {len(tasks)}"
    return tasks

@pytest.fixture(scope="function")
def authenticated_client(api_client, test_users):
    """Create authenticated API client"""
    user = test_users[0]
    
    # Login
    response = api_client.rpc("login", {
        "username": user["username"],
        "password": "testpass123"
    })
    
    assert response.status_code == 200
    login_data = response.json()
    assert "token" in login_data
    
    # Set auth token
    api_client.set_auth_token(login_data["token"])
    
    yield api_client
    
    # Cleanup - clear auth
    api_client.clear_auth()

@pytest.fixture(scope="function")
def clean_test_data(api_client):
    """Clean test data before and after each test"""
    # Reset data before test
    try:
        response = api_client.rpc("reset_test_data")
        if response.status_code not in [200, 204]:
            print(f"Warning: Could not reset test data: {response.status_code}")
    except Exception as e:
        print(f"Warning: Could not reset test data: {e}")
    
    yield
    
    # Reset data after test (optional, depends on test isolation needs)
    # Uncomment if you want complete isolation between tests
    # try:
    #     api_client.rpc("reset_test_data")
    # except Exception:
    #     pass  # Ignore cleanup errors

@pytest.fixture(scope="function")
def sample_completion(api_client, test_users, test_tasks):
    """Create a sample task completion for testing"""
    # Get an active assignment or create one
    response = api_client.get("/current_assignments?limit=1")
    assignments = response.json() if response.status_code == 200 else []
    
    if not assignments:
        # Create a test assignment
        user = test_users[0]
        task = test_tasks[0]
        
        # Create assignment (this might need adjustment based on your API)
        assignment_data = {
            "task_id": task["id"],
            "assigned_user_id": user["id"],
            "is_active": True
        }
        response = api_client.post("/task_assignments", assignment_data)
        if response.status_code not in [200, 201]:
            pytest.skip("Could not create test assignment")
        
        assignment = response.json()
    else:
        assignment = assignments[0]
    
    # Complete the task
    response = api_client.rpc("complete_task", {
        "task_assignment_id": assignment["id"],
        "completed_by_user_id": assignment["assigned_user_id"],
        "notes": "Test completion for fixture"
    })
    
    assert response.status_code == 200
    completion_data = response.json()
    
    return {
        "completion_id": completion_data["completion_id"],
        "assignment": assignment,
        "completion_data": completion_data
    }

def pytest_configure(config):
    """Configure pytest"""
    # Add custom markers
    config.addinivalue_line("markers", "slow: marks tests as slow")
    config.addinivalue_line("markers", "integration: marks tests as integration tests")
    config.addinivalue_line("markers", "unit: marks tests as unit tests")
    config.addinivalue_line("markers", "api: marks tests as API tests")
    config.addinivalue_line("markers", "database: marks tests that require database")

# Pytest collection hooks
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers automatically"""
    for item in items:
        # Add markers based on test path
        if "test_api" in str(item.fspath):
            item.add_marker(pytest.mark.api)
        if "test_integration" in str(item.fspath):
            item.add_marker(pytest.mark.integration)
        if "test_unit" in str(item.fspath):
            item.add_marker(pytest.mark.unit)

# Session-wide fixtures for database connection if needed
@pytest.fixture(scope="session")
def db_connection():
    """Direct database connection for advanced testing"""
    try:
        import psycopg2
        
        conn = psycopg2.connect(**POSTGRES_CONFIG)
        conn.autocommit = True
        
        yield conn
        
        conn.close()
    except ImportError:
        pytest.skip("psycopg2 not available for direct database testing")
    except Exception as e:
        pytest.skip(f"Could not connect to database: {e}")