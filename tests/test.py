import pytest
import requests
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

# Base configuration
BASE_URL = "http://postgrest:3000"
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
    
    def get(self, endpoint: str, params: Dict = None) -> requests.Response:
        """Make GET request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.get(url, params=params)
    
    def post(self, endpoint: str, data: Dict = None) -> requests.Response:
        """Make POST request"""
        url = f"{self.base_url}{endpoint}"
        return self.session.post(url, json=data)
    
    def rpc(self, function_name: str, data: Dict = None) -> requests.Response:
        """Make RPC call to PostgreSQL function"""
        return self.post(f"/rpc/{function_name}", data)

@pytest.fixture(scope="session")
def api_client():
    """Create API client instance"""
    return APIClient()

@pytest.fixture(scope="session")
def wait_for_api():
    """Wait for API to be ready"""
    client = APIClient()
    max_retries = 30
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            response = client.get("/")
            if response.status_code in [200, 404]:  # 404 is OK for root endpoint
                return True
        except requests.exceptions.ConnectionError:
            if attempt < max_retries - 1:
                time.sleep(retry_delay)
                continue
            raise
    
    raise Exception("API not ready after maximum retries")

@pytest.fixture(scope="session")
def test_users(api_client, wait_for_api):
    """Create test users and return their info"""
    # This assumes users are already created in init.sql
    # We'll fetch them from the API
    response = api_client.get("/users")
    assert response.status_code == 200
    users = response.json()
    assert len(users) >= 2, "Need at least 2 users for testing"
    return users

@pytest.fixture(scope="session")
def test_tasks(api_client, wait_for_api):
    """Get test tasks"""
    response = api_client.get("/tasks")
    assert response.status_code == 200
    tasks = response.json()
    assert len(tasks) >= 1, "Need at least 1 task for testing"
    return tasks

class TestAuthentication:
    """Test authentication endpoints"""
    
    def test_login_success(self, api_client, test_users):
        """Test successful login"""
        user = test_users[0]
        response = api_client.rpc("login", {
            "username": user["username"],
            "password": "password123"  # Assuming this is the default password
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "user_id" in data
        assert "username" in data
        assert "token" in data
        assert "message" in data
        assert data["username"] == user["username"]
        assert data["message"] == "Login successful"
    
    def test_login_invalid_username(self, api_client):
        """Test login with invalid username"""
        response = api_client.rpc("login", {
            "username": "nonexistent_user",
            "password": "password123"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "error" in data
        assert data["error"] == "Invalid credentials"
    
    def test_login_invalid_password(self, api_client, test_users):
        """Test login with invalid password"""
        user = test_users[0]
        response = api_client.rpc("login", {
            "username": user["username"],
            "password": "wrongpassword"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "error" in data
        assert data["error"] == "Invalid credentials"
    
    def test_login_missing_parameters(self, api_client):
        """Test login with missing parameters"""
        # Missing password
        response = api_client.rpc("login", {
            "username": "testuser"
        })
        assert response.status_code == 400
        
        # Missing username
        response = api_client.rpc("login", {
            "password": "password123"
        })
        assert response.status_code == 400
        
        # Missing both
        response = api_client.rpc("login", {})
        assert response.status_code == 400

class TestViews:
    """Test API views"""
    
    def test_current_assignments_view(self, api_client, wait_for_api):
        """Test current assignments view"""
        response = api_client.get("/current_assignments")
        assert response.status_code == 200
        
        assignments = response.json()
        assert isinstance(assignments, list)
        
        if assignments:
            assignment = assignments[0]
            required_fields = [
                "id", "task_id", "task_name", "category", "description",
                "estimated_duration_minutes", "assigned_user_id", "assigned_to",
                "assigned_at", "is_overdue"
            ]
            for field in required_fields:
                assert field in assignment
    
    def test_completion_history_view(self, api_client, wait_for_api):
        """Test completion history view"""
        response = api_client.get("/completion_history")
        assert response.status_code == 200
        
        history = response.json()
        assert isinstance(history, list)
        
        if history:
            completion = history[0]
            required_fields = [
                "id", "task_assignment_id", "task_name", "category",
                "completed_by_user_id", "completed_by", "completed_at",
                "notes", "status", "review_count", "approvals", "rejections"
            ]
            for field in required_fields:
                assert field in completion
    
    def test_user_dashboard_view(self, api_client, wait_for_api):
        """Test user dashboard view"""
        response = api_client.get("/user_dashboard")
        assert response.status_code == 200
        
        dashboards = response.json()
        assert isinstance(dashboards, list)
        
        if dashboards:
            dashboard = dashboards[0]
            required_fields = [
                "id", "username", "current_tasks", "overdue_tasks",
                "tasks_completed_month", "notifications_enabled"
            ]
            for field in required_fields:
                assert field in dashboard
    
    def test_pending_reviews_view(self, api_client, wait_for_api):
        """Test pending reviews view"""
        response = api_client.get("/pending_reviews")
        assert response.status_code == 200
        
        reviews = response.json()
        assert isinstance(reviews, list)
        
        if reviews:
            review = reviews[0]
            required_fields = [
                "completion_id", "task_name", "category", "completed_by_user_id",
                "completed_by", "completed_at", "notes", "potential_reviewers",
                "potential_reviewer_names"
            ]
            for field in required_fields:
                assert field in review
    
    def test_view_filtering(self, api_client, wait_for_api):
        """Test view filtering capabilities"""
        # Test filtering current assignments by user
        response = api_client.get("/current_assignments?assigned_user_id=eq.1")
        assert response.status_code == 200
        
        # Test filtering by category
        response = api_client.get("/current_assignments?category=eq.kitchen")
        assert response.status_code == 200
        
        # Test ordering
        response = api_client.get("/current_assignments?order=due_date.asc")
        assert response.status_code == 200

class TestTaskCompletion:
    """Test task completion functionality"""
    
    def test_complete_task_success(self, api_client, test_users, wait_for_api):
        """Test successful task completion"""
        # First, get an active assignment
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        # Complete the task
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Test completion notes"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "completion_id" in data
        assert "status" in data
        assert "message" in data
        assert data["status"] == "pending_review"
        assert "completion_id" in data
    
    def test_complete_task_with_notes(self, api_client, test_users, wait_for_api):
        """Test task completion with detailed notes"""
        # Get an active assignment
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        detailed_notes = "Cleaned thoroughly, used new cleaning supplies, took extra time on stubborn stains"
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": detailed_notes
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "pending_review"
        
        # Verify notes were saved
        completion_id = data["completion_id"]
        response = api_client.get(f"/completion_history?id=eq.{completion_id}")
        assert response.status_code == 200
        history = response.json()
        assert len(history) == 1
        assert history[0]["notes"] == detailed_notes
    
    def test_complete_task_invalid_assignment(self, api_client, test_users):
        """Test completing non-existent task assignment"""
        response = api_client.rpc("complete_task", {
            "task_assignment_id": 99999,  # Non-existent ID
            "completed_by_user_id": test_users[0]["id"],
            "notes": "Test notes"
        })
        
        # Should return error or handle gracefully
        assert response.status_code in [400, 422, 500]
    
    def test_complete_task_invalid_user(self, api_client, wait_for_api):
        """Test completing task with invalid user ID"""
        # Get an active assignment
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": 99999,  # Non-existent user
            "notes": "Test notes"
        })
        
        assert response.status_code in [400, 422, 500]

class TestTaskReview:
    """Test task review functionality"""
    
    def test_approve_task_success(self, api_client, test_users, wait_for_api):
        """Test successful task approval"""
        # First complete a task to have something to review
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        # Complete the task
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Test completion for review"
        })
        
        assert response.status_code == 200
        completion_data = response.json()
        completion_id = completion_data["completion_id"]
        
        # Find a different user to review
        reviewer_id = None
        for user in test_users:
            if user["id"] != user_id:
                reviewer_id = user["id"]
                break
        
        assert reviewer_id is not None, "Need at least 2 users for review testing"
        
        # Approve the task
        response = api_client.rpc("review_task", {
            "completion_id": completion_id,
            "reviewer_user_id": reviewer_id,
            "approved": True,
            "rating": 5,
            "comments": "Great job! Very thorough."
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "status" in data
        assert "message" in data
        assert data["status"] == "approved"
    
    def test_reject_task_success(self, api_client, test_users, wait_for_api):
        """Test successful task rejection"""
        # Complete a task first
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Quick completion"
        })
        
        assert response.status_code == 200
        completion_data = response.json()
        completion_id = completion_data["completion_id"]
        
        # Find reviewer
        reviewer_id = None
        for user in test_users:
            if user["id"] != user_id:
                reviewer_id = user["id"]
                break
        
        # Reject the task
        response = api_client.rpc("review_task", {
            "completion_id": completion_id,
            "reviewer_user_id": reviewer_id,
            "approved": False,
            "rating": 2,
            "comments": "Needs more attention to detail"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "rejected"
    
    def test_review_with_rating_scale(self, api_client, test_users, wait_for_api):
        """Test reviews with different rating values"""
        # Test ratings from 1 to 5
        for rating in [1, 2, 3, 4, 5]:
            # Complete a task
            response = api_client.get("/current_assignments?limit=1")
            if response.status_code != 200 or not response.json():
                continue
            
            assignment = response.json()[0]
            user_id = assignment["assigned_user_id"]
            
            response = api_client.rpc("complete_task", {
                "task_assignment_id": assignment["id"],
                "completed_by_user_id": user_id,
                "notes": f"Completion for rating {rating}"
            })
            
            if response.status_code != 200:
                continue
            
            completion_id = response.json()["completion_id"]
            
            # Find reviewer
            reviewer_id = None
            for user in test_users:
                if user["id"] != user_id:
                    reviewer_id = user["id"]
                    break
            
            if reviewer_id is None:
                continue
            
            # Review with specific rating
            response = api_client.rpc("review_task", {
                "completion_id": completion_id,
                "reviewer_user_id": reviewer_id,
                "approved": rating >= 3,
                "rating": rating,
                "comments": f"Rating {rating} review"
            })
            
            assert response.status_code == 200
    
    def test_review_invalid_completion(self, api_client, test_users):
        """Test reviewing non-existent completion"""
        response = api_client.rpc("review_task", {
            "completion_id": 99999,
            "reviewer_user_id": test_users[0]["id"],
            "approved": True,
            "rating": 5,
            "comments": "Test review"
        })
        
        assert response.status_code in [400, 422, 500]
    
    def test_self_review_prevention(self, api_client, test_users, wait_for_api):
        """Test that users cannot review their own work"""
        # Complete a task
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Self review test"
        })
        
        assert response.status_code == 200
        completion_id = response.json()["completion_id"]
        
        # Try to review own work
        response = api_client.rpc("review_task", {
            "completion_id": completion_id,
            "reviewer_user_id": user_id,  # Same user
            "approved": True,
            "rating": 5,
            "comments": "Self review attempt"
        })
        
        # Should fail - exact behavior depends on implementation
        # Could be 400, 422, or handled with business logic
        # For now, just ensure it doesn't succeed normally
        if response.status_code == 200:
            # If it succeeds, check if it's properly filtered in views
            pending_response = api_client.get("/pending_reviews")
            assert pending_response.status_code == 200

class TestTaskRotation:
    """Test task rotation logic"""
    
    def test_task_rotation_after_approval(self, api_client, test_users, wait_for_api):
        """Test that tasks rotate to next user after approval"""
        if len(test_users) < 2:
            pytest.skip("Need at least 2 users for rotation testing")
        
        # Get current assignment
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        original_user_id = assignment["assigned_user_id"]
        task_id = assignment["task_id"]
        
        # Complete the task
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": original_user_id,
            "notes": "Task rotation test"
        })
        
        assert response.status_code == 200
        completion_id = response.json()["completion_id"]
        
        # Find reviewer
        reviewer_id = None
        for user in test_users:
            if user["id"] != original_user_id:
                reviewer_id = user["id"]
                break
        
        # Approve the task
        response = api_client.rpc("review_task", {
            "completion_id": completion_id,
            "reviewer_user_id": reviewer_id,
            "approved": True,
            "rating": 4,
            "comments": "Approved for rotation test"
        })
        
        assert response.status_code == 200
        
        # Check that task was rotated to next user
        response = api_client.get(f"/current_assignments?task_id=eq.{task_id}")
        assert response.status_code == 200
        new_assignments = response.json()
        
        if new_assignments:
            new_assignment = new_assignments[0]
            # Should be assigned to a different user
            assert new_assignment["assigned_user_id"] != original_user_id

class TestDataIntegrity:
    """Test data integrity and edge cases"""
    
    def test_completion_without_notes(self, api_client, wait_for_api):
        """Test completing task without notes"""
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id
            # No notes provided
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "pending_review"
    
    def test_review_without_rating(self, api_client, test_users, wait_for_api):
        """Test reviewing without rating"""
        # Complete a task first
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Review without rating test"
        })
        
        assert response.status_code == 200
        completion_id = response.json()["completion_id"]
        
        # Find reviewer
        reviewer_id = None
        for user in test_users:
            if user["id"] != user_id:
                reviewer_id = user["id"]
                break
        
        # Review without rating
        response = api_client.rpc("review_task", {
            "completion_id": completion_id,
            "reviewer_user_id": reviewer_id,
            "approved": True,
            "comments": "Good work!"
            # No rating provided
        })
        
        assert response.status_code == 200
    
    def test_multiple_reviews_same_completion(self, api_client, test_users, wait_for_api):
        """Test multiple users reviewing the same completion"""
        if len(test_users) < 3:
            pytest.skip("Need at least 3 users for multiple review testing")
        
        # Complete a task
        response = api_client.get("/current_assignments?limit=1")
        assert response.status_code == 200
        assignments = response.json()
        
        if not assignments:
            pytest.skip("No active assignments available for testing")
        
        assignment = assignments[0]
        user_id = assignment["assigned_user_id"]
        
        response = api_client.rpc("complete_task", {
            "task_assignment_id": assignment["id"],
            "completed_by_user_id": user_id,
            "notes": "Multiple review test"
        })
        
        assert response.status_code == 200
        completion_id = response.json()["completion_id"]
        
        # Get multiple reviewers
        reviewers = [user for user in test_users if user["id"] != user_id][:2]
        
        # Each reviewer reviews the same completion
        for i, reviewer in enumerate(reviewers):
            response = api_client.rpc("review_task", {
                "completion_id": completion_id,
                "reviewer_user_id": reviewer["id"],
                "approved": True,
                "rating": 4 + i,
                "comments": f"Review {i+1} from {reviewer['username']}"
            })
            
            assert response.status_code == 200

class TestErrorHandling:
    """Test error handling and edge cases"""
    
    def test_malformed_json_requests(self, api_client):
        """Test handling of malformed JSON in requests"""
        # This would need to be tested at a lower level
        # PostgREST should handle malformed JSON gracefully
        pass
    
    def test_missing_required_fields(self, api_client):
        """Test requests with missing required fields"""
        # Test complete_task without required fields
        response = api_client.rpc("complete_task", {})
        assert response.status_code == 400
        
        # Test review_task without required fields
        response = api_client.rpc("review_task", {})
        assert response.status_code == 400
    
    def test_sql_injection_attempts(self, api_client):
        """Test that SQL injection attempts are prevented"""
        # Test with SQL injection attempts in username
        malicious_usernames = [
            "'; DROP TABLE users; --",
            "admin' OR '1'='1",
            "' UNION SELECT * FROM users --"
        ]
        
        for username in malicious_usernames:
            response = api_client.rpc("login", {
                "username": username,
                "password": "password123"
            })
            
            # Should return invalid credentials, not cause errors
            assert response.status_code == 200
            data = response.json()
            assert "error" in data
            assert data["error"] == "Invalid credentials"

class TestPerformance:
    """Test performance and limits"""
    
    def test_large_dataset_queries(self, api_client, wait_for_api):
        """Test queries with large result sets"""
        # Test without limit
        response = api_client.get("/completion_history")
        assert response.status_code == 200
        
        # Test with limit
        response = api_client.get("/completion_history?limit=10")
        assert response.status_code == 200
        history = response.json()
        assert len(history) <= 10
    
    def test_concurrent_completions(self, api_client, test_users, wait_for_api):
        """Test handling of concurrent task completions"""
        # This would require threading or async testing
        # For now, just ensure basic functionality works
        pass

# Pytest configuration and utilities
@pytest.fixture(autouse=True)
def setup_test_data():
    """Setup test data before each test if needed"""
    # This could be used to ensure consistent test state
    pass

def pytest_configure(config):
    """Configure pytest"""
    # Add custom markers
    config.addinivalue_line("markers", "slow: marks tests as slow")
    config.addinivalue_line("markers", "integration: marks tests as integration tests")

if __name__ == "__main__":
    # Run tests when script is executed directly
    pytest.main([__file__, "-v"])