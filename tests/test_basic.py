import pytest
import requests

def test_postgrest_is_accessible(api_client):
    """Test that PostgREST API is accessible."""
    response = api_client.get('/')
    assert response.status_code == 200, f"API should be accessible. Status: {response.status_code}"

def test_database_connection(db_connection):
    """Test that database connection works."""
    with db_connection.cursor() as cursor:
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        assert result[0] == 1

def test_pgcrypto_extension_available(db_connection):
    """Test that pgcrypto extension is available."""
    with db_connection.cursor() as cursor:
        cursor.execute("SELECT crypt('test', gen_salt('bf'))")
        result = cursor.fetchone()
        assert result[0] is not None
        assert len(result[0]) > 0

def test_users_table_exists(db_connection):
    """Test that users table exists and has expected structure."""
    with db_connection.cursor() as cursor:
        cursor.execute("""
            SELECT column_name, data_type 
            FROM information_schema.columns 
            WHERE table_name = 'users' AND table_schema = 'public'
            ORDER BY ordinal_position
        """)
        columns = cursor.fetchall()
        
        # Check that essential columns exist
        column_names = [col[0] for col in columns]
        assert 'user_id' in column_names
        assert 'username' in column_names
        assert 'password_hash' in column_names

def test_api_schema_exists(db_connection):
    """Test that api schema exists."""
    with db_connection.cursor() as cursor:
        cursor.execute("""
            SELECT schema_name 
            FROM information_schema.schemata 
            WHERE schema_name = 'api'
        """)
        result = cursor.fetchone()
        assert result is not None, "API schema should exist" 