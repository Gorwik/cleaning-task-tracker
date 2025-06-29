import pytest
import requests
import psycopg2
from psycopg2.extras import RealDictCursor
import time

# Database connection fixture
@pytest.fixture(scope='module')
def db_connection():
    """Database connection fixture for direct database testing."""
    conn_str = "host=localhost dbname=cleaning_tracker user=cleaning_user password=cleaning_pass"
    try:
        conn = psycopg2.connect(conn_str)
        yield conn
        conn.close()
    except psycopg2.OperationalError as e:
        pytest.fail(f"DB connection failed: {e}")

# API client fixture
@pytest.fixture(scope='module')
def api_client():
    """API client fixture for testing PostgREST endpoints."""
    base_url = "http://localhost:3000"
    
    # Wait for API to be ready
    max_retries = 30
    for i in range(max_retries):
        try:
            response = requests.get(f"{base_url}/")
            if response.status_code == 200:
                break
        except requests.exceptions.ConnectionError:
            if i == max_retries - 1:
                pytest.fail("API not accessible after 30 retries")
            time.sleep(1)
    
    # Create a session with the base URL configured
    session = requests.Session()
    
    # Override the request method to prepend base_url for relative URLs
    original_request = session.request
    
    def request_with_base_url(method, url, *args, **kwargs):
        if not url.startswith('http'):
            url = f"{base_url}{url}"
        return original_request(method, url, *args, **kwargs)
    
    session.request = request_with_base_url
    return session

# Fixture to clean the database before tests
@pytest.fixture(autouse=True)
def clean_db(db_connection):
    """Clean database and reset to initial state before each test."""
    with db_connection.cursor() as cursor:
        # Truncate all tables and restart sequences
        cursor.execute("""
            TRUNCATE public.users, public.tasks, public.task_assignments 
            RESTART IDENTITY CASCADE
        """)
        
        # Re-seed with test data
        cursor.execute("""
            INSERT INTO public.users (username, password_hash) VALUES
            ('user1', crypt('password123', gen_salt('bf'))),
            ('user2', crypt('password123', gen_salt('bf'))),
            ('user3', crypt('password123', gen_salt('bf')));
        """)
        
        cursor.execute("""
            INSERT INTO public.tasks (task_name, description) VALUES
            ('Kitchen Cleaning', 'Clean the kitchen surfaces and floor.'),
            ('Bathroom Cleaning', 'Clean the toilet, shower, and sink.'),
            ('Living Room Tidying', 'Tidy up the living room area.'),
            ('Trash Duty', 'Take out the trash and recycling.'),
            ('Vacuuming', 'Vacuum all carpets and rugs.'),
            ('Dishwashing', 'Wash all dirty dishes.');
        """)
        
        cursor.execute("""
            INSERT INTO public.task_assignments (task_id, user_id) VALUES
            (1, 1), (2, 2), (3, 3), (4, 1), (5, 2), (6, 3);
        """)
        
    db_connection.commit() 