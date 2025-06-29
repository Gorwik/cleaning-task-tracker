import pytest
import requests

class TestUserRegistration:
    """Test user registration functionality."""
    
    def test_register_user_success(self, api_client):
        """Test successful user registration."""
        response = api_client.post('/rpc/register_user', json={
            'p_username': 'newuser',
            'p_password': 'securepassword123'
        })
        
        assert response.status_code == 201
        data = response.json()
        assert 'user_id' in data
        assert data['username'] == 'newuser'
        assert 'message' in data
        assert data['message'] == 'User registered successfully'
    
    def test_register_user_duplicate_username(self, api_client):
        """Test registration with existing username fails."""
        # First registration should succeed
        response1 = api_client.post('/rpc/register_user', json={
            'p_username': 'duplicateuser',
            'p_password': 'password123'
        })
        assert response1.status_code == 201
        
        # Second registration with same username should fail
        response2 = api_client.post('/rpc/register_user', json={
            'p_username': 'duplicateuser',
            'p_password': 'differentpassword'
        })
        
        assert response2.status_code == 400
        data = response2.json()
        assert 'error' in data
        assert 'already exists' in data['error'].lower()
    
    def test_register_user_empty_username(self, api_client):
        """Test registration with empty username fails."""
        response = api_client.post('/rpc/register_user', json={
            'p_username': '',
            'p_password': 'password123'
        })
        
        assert response.status_code == 400
        data = response.json()
        assert 'error' in data
    
    def test_register_user_empty_password(self, api_client):
        """Test registration with empty password fails."""
        response = api_client.post('/rpc/register_user', json={
            'p_username': 'testuser',
            'p_password': ''
        })
        
        assert response.status_code == 400
        data = response.json()
        assert 'error' in data
    
    def test_register_user_missing_parameters(self, api_client):
        """Test registration with missing parameters fails."""
        response = api_client.post('/rpc/register_user', json={
            'p_username': 'testuser'
            # Missing p_password
        })
        
        assert response.status_code == 404
        # PostgREST returns 404 when function parameters don't match

class TestUserLogin:
    """Test user login functionality."""
    
    def test_login_success(self, api_client):
        """Test successful login with valid credentials."""
        response = api_client.post('/rpc/login', json={
            'p_username': 'user1',
            'p_password': 'password123'
        })
        
        assert response.status_code == 200
        data = response.json()
        assert 'user_id' in data
        assert data['username'] == 'user1'
        assert 'message' in data
        assert data['message'] == 'Login successful'
    
    def test_login_invalid_username(self, api_client):
        """Test login with non-existent username fails."""
        response = api_client.post('/rpc/login', json={
            'p_username': 'nonexistentuser',
            'p_password': 'password123'
        })
        
        assert response.status_code == 401
        data = response.json()
        assert 'error' in data
        assert 'invalid' in data['error'].lower()
    
    def test_login_invalid_password(self, api_client):
        """Test login with wrong password fails."""
        response = api_client.post('/rpc/login', json={
            'p_username': 'user1',
            'p_password': 'wrongpassword'
        })
        
        assert response.status_code == 401
        data = response.json()
        assert 'error' in data
        assert 'invalid' in data['error'].lower()
    
    def test_login_empty_username(self, api_client):
        """Test login with empty username fails."""
        response = api_client.post('/rpc/login', json={
            'p_username': '',
            'p_password': 'password123'
        })
        
        assert response.status_code == 401
        data = response.json()
        assert 'error' in data
    
    def test_login_empty_password(self, api_client):
        """Test login with empty password fails."""
        response = api_client.post('/rpc/login', json={
            'p_username': 'user1',
            'p_password': ''
        })
        
        assert response.status_code == 401
        data = response.json()
        assert 'error' in data
    
    def test_login_missing_parameters(self, api_client):
        """Test login with missing parameters fails."""
        response = api_client.post('/rpc/login', json={
            'p_username': 'user1'
            # Missing p_password
        })
        
        assert response.status_code == 404
        # PostgREST returns 404 when function parameters don't match

class TestPasswordHashing:
    """Test password hashing functionality."""
    
    def test_password_hashing_verification(self, db_connection):
        """Test that password hashing and verification works correctly."""
        with db_connection.cursor() as cursor:
            # Test password verification
            cursor.execute("""
                SELECT (password_hash = crypt('password123', password_hash)) as is_valid
                FROM public.users WHERE username = 'user1'
            """)
            result = cursor.fetchone()
            assert result[0] is True
            
            # Test wrong password fails
            cursor.execute("""
                SELECT (password_hash = crypt('wrongpassword', password_hash)) as is_valid
                FROM public.users WHERE username = 'user1'
            """)
            result = cursor.fetchone()
            assert result[0] is False
    
    def test_new_user_password_hashing(self, db_connection):
        """Test that new users get properly hashed passwords."""
        with db_connection.cursor() as cursor:
            # Insert a new user
            cursor.execute("""
                INSERT INTO public.users (username, password_hash)
                VALUES ('testuser', crypt('testpassword', gen_salt('bf')))
                RETURNING user_id
            """)
            user_id = cursor.fetchone()[0]
            
            # Verify the password
            cursor.execute("""
                SELECT (password_hash = crypt('testpassword', password_hash)) as is_valid
                FROM public.users WHERE user_id = %s
            """, (user_id,))
            result = cursor.fetchone()
            assert result[0] is True

class TestAuthenticationIntegration:
    """Test integration between registration and login."""
    
    def test_register_then_login(self, api_client):
        """Test that a newly registered user can login."""
        # Register a new user
        register_response = api_client.post('/rpc/register_user', json={
            'p_username': 'integrationtest',
            'p_password': 'integrationpass123'
        })
        
        assert register_response.status_code == 201
        register_data = register_response.json()
        user_id = register_data['user_id']
        
        # Login with the same credentials
        login_response = api_client.post('/rpc/login', json={
            'p_username': 'integrationtest',
            'p_password': 'integrationpass123'
        })
        
        assert login_response.status_code == 200
        login_data = login_response.json()
        assert login_data['user_id'] == user_id
        assert login_data['username'] == 'integrationtest'
    
    def test_register_then_login_wrong_password(self, api_client):
        """Test that login fails with wrong password after registration."""
        # Register a new user
        register_response = api_client.post('/rpc/register_user', json={
            'p_username': 'wrongpassuser',
            'p_password': 'correctpassword'
        })
        
        assert register_response.status_code == 201
        
        # Try to login with wrong password
        login_response = api_client.post('/rpc/login', json={
            'p_username': 'wrongpassuser',
            'p_password': 'wrongpassword'
        })
        
        assert login_response.status_code == 401
        data = login_response.json()
        assert 'error' in data 