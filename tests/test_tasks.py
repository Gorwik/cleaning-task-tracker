import pytest
import requests

class TestTaskManagement:
    """Test task management functionality."""
    
    def test_create_task_success(self, api_client):
        """Test successful task creation."""
        response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'New Test Task',
            'p_description': 'A test task for cleaning'
        })
        
        assert response.status_code == 201
        data = response.json()
        assert 'task_id' in data
        assert data['task_name'] == 'New Test Task'
        assert data['description'] == 'A test task for cleaning'
        assert 'message' in data
    
    def test_create_task_duplicate_name(self, api_client):
        """Test that creating a task with duplicate name fails."""
        # First creation should succeed
        response1 = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Duplicate Task',
            'p_description': 'First task'
        })
        assert response1.status_code == 201
        
        # Second creation with same name should fail
        response2 = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Duplicate Task',
            'p_description': 'Second task'
        })
        
        assert response2.status_code == 400
        data = response2.json()
        assert 'error' in data
        assert 'already exists' in data['error'].lower()
    
    def test_create_task_empty_name(self, api_client):
        """Test that creating a task with empty name fails."""
        response = api_client.post('/rpc/create_task', json={
            'p_task_name': '',
            'p_description': 'Test description'
        })
        
        assert response.status_code == 400
        data = response.json()
        assert 'error' in data
    
    def test_create_task_missing_parameters(self, api_client):
        """Test that creating a task with missing parameters fails."""
        response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Test Task'
            # Missing p_description
        })
        
        assert response.status_code == 404  # PostgREST returns 404 for missing parameters
    
    def test_get_all_tasks(self, api_client):
        """Test retrieving all tasks."""
        response = api_client.get('/tasks')
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 6  # Should have at least 6 tasks from seed data
        
        # Check that tasks have required fields
        if data:
            task = data[0]
            assert 'task_id' in task
            assert 'task_name' in task
            assert 'description' in task
    
    def test_get_task_by_id(self, api_client):
        """Test retrieving a specific task by ID."""
        response = api_client.get('/tasks?task_id=eq.1')
        
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]['task_id'] == 1
        assert 'task_name' in data[0]

class TestTaskAssignment:
    """Test task assignment functionality."""
    
    def test_assign_task_to_user_success(self, api_client):
        """Test successful task assignment."""
        # Create a new task first to ensure it's not already assigned
        create_response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Test Assignment Task',
            'p_description': 'Task for testing assignment'
        })
        assert create_response.status_code == 201
        task_data = create_response.json()
        task_id = task_data['task_id']
        
        # Now assign the task
        response = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 1
        })
        
        assert response.status_code == 201
        data = response.json()
        assert 'assignment_id' in data
        assert data['task_id'] == task_id
        assert data['user_id'] == 1
        assert 'message' in data
    
    def test_assign_task_invalid_task_id(self, api_client):
        """Test assignment with non-existent task ID fails."""
        response = api_client.post('/rpc/assign_task', json={
            'p_task_id': 999,
            'p_user_id': 1
        })
        
        assert response.status_code == 404
        data = response.json()
        assert 'error' in data
    
    def test_assign_task_invalid_user_id(self, api_client):
        """Test assignment with non-existent user ID fails."""
        response = api_client.post('/rpc/assign_task', json={
            'p_task_id': 1,
            'p_user_id': 999
        })
        
        assert response.status_code == 404
        data = response.json()
        assert 'error' in data
    
    def test_assign_task_already_assigned(self, api_client):
        """Test that assigning an already assigned task fails."""
        # Create a new task first
        create_response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Test Already Assigned Task',
            'p_description': 'Task for testing duplicate assignment'
        })
        assert create_response.status_code == 201
        task_data = create_response.json()
        task_id = task_data['task_id']
        
        # First assignment should succeed
        response1 = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 2
        })
        assert response1.status_code == 201
        
        # Second assignment of same task should fail
        response2 = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 3
        })
        
        assert response2.status_code == 400
        data = response2.json()
        assert 'error' in data
    
    def test_get_user_assignments(self, api_client):
        """Test retrieving assignments for a specific user."""
        response = api_client.get('/task_assignments?user_id=eq.1')
        
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        
        # Check that all assignments belong to user 1
        for assignment in data:
            assert assignment['user_id'] == 1

class TestTaskCompletion:
    """Test task completion functionality."""
    
    def test_complete_task_success(self, api_client):
        """Test successful task completion."""
        response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': 1,
            'p_user_id': 1,
            'p_notes': 'Task completed successfully'
        })
        
        assert response.status_code == 200
        data = response.json()
        assert 'message' in data
        assert 'completed' in data['message'].lower()
    
    def test_complete_task_wrong_user(self, api_client):
        """Test that completing another user's task fails."""
        response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': 1,
            'p_user_id': 2,  # Different user
            'p_notes': 'Trying to complete someone else\'s task'
        })
        
        assert response.status_code == 403
        data = response.json()
        assert 'error' in data
    
    def test_complete_task_already_completed(self, api_client):
        """Test that completing an already completed task fails."""
        # First completion should succeed
        response1 = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': 2,
            'p_user_id': 2,
            'p_notes': 'First completion'
        })
        assert response1.status_code == 200
        
        # Second completion should fail
        response2 = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': 2,
            'p_user_id': 2,
            'p_notes': 'Second completion'
        })
        
        assert response2.status_code == 400
        data = response2.json()
        assert 'error' in data
    
    def test_complete_task_invalid_assignment(self, api_client):
        """Test completing non-existent assignment fails."""
        response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': 999,
            'p_user_id': 1,
            'p_notes': 'Invalid assignment'
        })
        
        assert response.status_code == 404
        data = response.json()
        assert 'error' in data

class TestTaskRotation:
    """Test automatic task rotation functionality."""
    
    def test_rotate_tasks_success(self, api_client):
        """Test successful task rotation."""
        response = api_client.post('/rpc/rotate_tasks', json={})
        
        assert response.status_code == 200
        data = response.json()
        assert 'message' in data
        assert 'rotated' in data['message'].lower()
    
    def test_rotation_creates_new_assignments(self, api_client):
        """Test that rotation creates new assignments."""
        # Get initial assignment count
        initial_response = api_client.get('/task_assignments')
        initial_count = len(initial_response.json())
        
        # Perform rotation
        rotation_response = api_client.post('/rpc/rotate_tasks', json={})
        assert rotation_response.status_code == 200
        
        # Check that new assignments were created
        final_response = api_client.get('/task_assignments')
        final_count = len(final_response.json())
        
        assert final_count > initial_count
    
    def test_rotation_distributes_evenly(self, api_client):
        """Test that rotation distributes tasks evenly among users."""
        # Perform rotation
        response = api_client.post('/rpc/rotate_tasks', json={})
        assert response.status_code == 200
        
        # Get assignments for each user
        user1_assignments = api_client.get('/task_assignments?user_id=eq.1').json()
        user2_assignments = api_client.get('/task_assignments?user_id=eq.2').json()
        user3_assignments = api_client.get('/task_assignments?user_id=eq.3').json()
        
        # Check that assignments are distributed (allow some variance)
        counts = [len(user1_assignments), len(user2_assignments), len(user3_assignments)]
        max_count = max(counts)
        min_count = min(counts)
        
        # Should be reasonably distributed (no more than 2 difference)
        assert max_count - min_count <= 2

class TestTaskRejection:
    """Test task rejection and redo functionality."""

    def test_reject_and_redo_task(self, api_client):
        """Test that a rejected task can be redone and reviewed again."""
        # Create and assign a task
        create_response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Redo Test Task',
            'p_description': 'Test redo after rejection'
        })
        assert create_response.status_code == 201
        task_id = create_response.json()['task_id']

        assign_response = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 1
        })
        assert assign_response.status_code == 201
        assignment_id = assign_response.json()['assignment_id']

        # Complete the task
        complete_response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': assignment_id,
            'p_user_id': 1,
            'p_notes': 'Done'
        })
        assert complete_response.status_code == 200

        # Reject the task
        reject_response = api_client.post('/rpc/reject_task', json={
            'p_assignment_id': assignment_id,
            'p_reviewer_id': 2,
            'p_reason': 'Not good enough'
        })
        assert reject_response.status_code == 200

        # Fetch assignment and check is_approved is false, completed_at is set
        assignments_response = api_client.get(f'/task_assignments?assignment_id=eq.{assignment_id}')
        assert assignments_response.status_code == 200
        assignment = assignments_response.json()[0]
        assert assignment['is_approved'] is False
        assert assignment['completed_at'] is not None

        # Redo (complete) the rejected task
        redo_response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': assignment_id,
            'p_user_id': 1,
            'p_notes': 'Redone'
        })
        assert redo_response.status_code == 200

        # Fetch assignment and check is_approved is null, completed_at is updated
        assignments_response = api_client.get(f'/task_assignments?assignment_id=eq.{assignment_id}')
        assert assignments_response.status_code == 200
        assignment = assignments_response.json()[0]
        assert assignment['is_approved'] is None
        assert assignment['completed_at'] is not None

        # Approve the redone task
        # (simulate review by directly updating is_approved for test, or use reject_task with approve logic if available)
        # For now, just check that the workflow allows redo and resets state

    def test_cannot_complete_already_completed_task(self, api_client):
        """Test that completing an already completed and not rejected task returns an error."""
        # Create and assign a task
        create_response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Already Completed Task',
            'p_description': 'Should not allow double complete'
        })
        assert create_response.status_code == 201
        task_id = create_response.json()['task_id']

        assign_response = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 1
        })
        assert assign_response.status_code == 201
        assignment_id = assign_response.json()['assignment_id']

        # Complete the task
        complete_response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': assignment_id,
            'p_user_id': 1,
            'p_notes': 'Done'
        })
        assert complete_response.status_code == 200

        # Try to complete again (should fail)
        redo_response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': assignment_id,
            'p_user_id': 1,
            'p_notes': 'Trying to double complete'
        })
        assert redo_response.status_code == 400
        data = redo_response.json()
        assert 'error' in data

class TestTaskIntegration:
    """Test integration between different task operations."""
    
    def test_full_task_workflow(self, api_client):
        """Test complete task workflow: create -> assign -> complete -> reject -> reassign."""
        # 1. Create a new task
        create_response = api_client.post('/rpc/create_task', json={
            'p_task_name': 'Integration Test Task',
            'p_description': 'Test workflow'
        })
        assert create_response.status_code == 201
        task_data = create_response.json()
        task_id = task_data['task_id']
        
        # 2. Assign the task
        assign_response = api_client.post('/rpc/assign_task', json={
            'p_task_id': task_id,
            'p_user_id': 1
        })
        assert assign_response.status_code == 201
        assignment_data = assign_response.json()
        assignment_id = assignment_data['assignment_id']
        
        # 3. Complete the task
        complete_response = api_client.post('/rpc/complete_task', json={
            'p_assignment_id': assignment_id,
            'p_user_id': 1,
            'p_notes': 'Completed for testing'
        })
        assert complete_response.status_code == 200
        
        # 4. Reject the task
        reject_response = api_client.post('/rpc/reject_task', json={
            'p_assignment_id': assignment_id,
            'p_reviewer_id': 2,
            'p_reason': 'Not done properly'
        })
        assert reject_response.status_code == 200
        
        # 5. Verify task is NOT reassigned (should only be one assignment)
        assignments_response = api_client.get(f'/task_assignments?task_id=eq.{task_id}')
        assert assignments_response.status_code == 200
        assignments = assignments_response.json()
        # Should have only one assignment for this task
        assert len(assignments) == 1
        assert assignments[0]['assignment_id'] == assignment_id
        assert assignments[0]['user_id'] == 1
        assert assignments[0]['is_approved'] is False 