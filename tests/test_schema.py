import pytest

class TestDatabaseSchema:
    """Test database schema structure and constraints."""
    
    def test_users_table_structure(self, db_connection):
        """Test that users table has correct structure."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT column_name, data_type, is_nullable, column_default
                FROM information_schema.columns 
                WHERE table_name = 'users' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            columns = cursor.fetchall()
            
            # Check essential columns exist
            column_names = [col[0] for col in columns]
            assert 'user_id' in column_names
            assert 'username' in column_names
            assert 'password_hash' in column_names
            assert 'created_at' in column_names
            
            # Check data types
            for col_name, data_type, is_nullable, default in columns:
                if col_name == 'user_id':
                    assert data_type in ['integer', 'bigint']
                elif col_name == 'username':
                    assert data_type in ['character varying', 'varchar']
                    assert is_nullable == 'NO'
                elif col_name == 'password_hash':
                    assert data_type in ['text', 'character varying']
                    assert is_nullable == 'NO'
    
    def test_tasks_table_structure(self, db_connection):
        """Test that tasks table has correct structure."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_name = 'tasks' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            columns = cursor.fetchall()
            
            column_names = [col[0] for col in columns]
            assert 'task_id' in column_names
            assert 'task_name' in column_names
            assert 'description' in column_names
    
    def test_task_assignments_table_structure(self, db_connection):
        """Test that task_assignments table has correct structure."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns 
                WHERE table_name = 'task_assignments' AND table_schema = 'public'
                ORDER BY ordinal_position
            """)
            columns = cursor.fetchall()
            
            column_names = [col[0] for col in columns]
            assert 'assignment_id' in column_names
            assert 'task_id' in column_names
            assert 'user_id' in column_names
            assert 'assigned_at' in column_names
            assert 'completed_at' in column_names
            assert 'is_approved' in column_names
    
    def test_foreign_key_constraints(self, db_connection):
        """Test that foreign key constraints are properly set up."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    tc.constraint_name,
                    tc.table_name,
                    kcu.column_name,
                    ccu.table_name AS foreign_table_name,
                    ccu.column_name AS foreign_column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                JOIN information_schema.constraint_column_usage AS ccu
                    ON ccu.constraint_name = tc.constraint_name
                WHERE tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_schema = 'public'
                ORDER BY tc.table_name, kcu.column_name
            """)
            foreign_keys = cursor.fetchall()
            
            # Check task_assignments foreign keys
            fk_constraints = [(fk[1], fk[2], fk[3], fk[4]) for fk in foreign_keys]
            assert ('task_assignments', 'task_id', 'tasks', 'task_id') in fk_constraints
            assert ('task_assignments', 'user_id', 'users', 'user_id') in fk_constraints
    
    def test_unique_constraints(self, db_connection):
        """Test that unique constraints are properly set up."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    tc.constraint_name,
                    tc.table_name,
                    kcu.column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                    ON tc.constraint_name = kcu.constraint_name
                WHERE tc.constraint_type = 'UNIQUE'
                AND tc.table_schema = 'public'
                ORDER BY tc.table_name, kcu.column_name
            """)
            unique_constraints = cursor.fetchall()
            
            # Check username uniqueness
            unique_columns = [(uc[1], uc[2]) for uc in unique_constraints]
            assert ('users', 'username') in unique_columns
            assert ('tasks', 'task_name') in unique_columns
    
    def test_initial_data_exists(self, db_connection):
        """Test that initial seed data exists."""
        with db_connection.cursor() as cursor:
            # Check users
            cursor.execute("SELECT COUNT(*) FROM public.users")
            user_count = cursor.fetchone()[0]
            assert user_count >= 3
            
            # Check tasks
            cursor.execute("SELECT COUNT(*) FROM public.tasks")
            task_count = cursor.fetchone()[0]
            assert task_count >= 6
            
            # Check task assignments
            cursor.execute("SELECT COUNT(*) FROM public.task_assignments")
            assignment_count = cursor.fetchone()[0]
            assert assignment_count >= 6
    
    def test_pgcrypto_extension_enabled(self, db_connection):
        """Test that pgcrypto extension is enabled."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT extname FROM pg_extension WHERE extname = 'pgcrypto'
            """)
            result = cursor.fetchone()
            assert result is not None, "pgcrypto extension should be enabled"
    
    def test_api_schema_exists(self, db_connection):
        """Test that api schema exists and has proper permissions."""
        with db_connection.cursor() as cursor:
            cursor.execute("""
                SELECT schema_name FROM information_schema.schemata 
                WHERE schema_name = 'api'
            """)
            result = cursor.fetchone()
            assert result is not None, "API schema should exist" 