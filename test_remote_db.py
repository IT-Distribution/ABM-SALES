import psycopg2
from psycopg2 import OperationalError
import os
from sqlalchemy import create_engine
from sqlalchemy.exc import OperationalError as SQLAlchemyOperationalError

# Database URL from your configuration
DATABASE_URL = "postgresql+psycopg2://abmsalesdatabase:rTzYrF3GO4b0bzCNtsmdzuaAYnnfPmJN@dpg-d1g0cmali9vc73a392lg-a/abmsalesdatabase"

def test_psycopg2_connection():
    """Test direct psycopg2 connection"""
    print("🔍 Testing direct psycopg2 connection...")
    try:
        # Extract connection parameters from URL
        # postgresql+psycopg2://user:password@host/database
        parts = DATABASE_URL.replace("postgresql+psycopg2://", "").split("@")
        user_pass = parts[0].split(":")
        user = user_pass[0]
        password = user_pass[1]
        host_db = parts[1].split("/")
        host = host_db[0]
        database = host_db[1]
        
        print(f"Connecting to: {host}")
        print(f"Database: {database}")
        print(f"User: {user}")
        
        connection = psycopg2.connect(
            host=host,
            database=database,
            user=user,
            password=password,
            connect_timeout=10
        )
        
        if connection:
            print("✅ Direct psycopg2 connection successful!")
            cursor = connection.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()
            print(f"PostgreSQL version: {version[0]}")
            connection.close()
            return True
            
    except OperationalError as e:
        print(f"❌ Direct psycopg2 connection failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_sqlalchemy_connection():
    """Test SQLAlchemy connection"""
    print("\n🔍 Testing SQLAlchemy connection...")
    try:
        engine = create_engine(DATABASE_URL, connect_args={"connect_timeout": 10})
        with engine.connect() as connection:
            result = connection.execute("SELECT version();")
            version = result.fetchone()
            print(f"✅ SQLAlchemy connection successful!")
            print(f"PostgreSQL version: {version[0]}")
            return True
    except SQLAlchemyOperationalError as e:
        print(f"❌ SQLAlchemy connection failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def suggest_solutions():
    """Provide solutions for common connection issues"""
    print("\n" + "="*60)
    print("🔧 POSSIBLE SOLUTIONS:")
    print("="*60)
    
    print("\n1. 🌐 NETWORK CONNECTIVITY:")
    print("   - Check if you can reach the database host from your machine")
    print("   - Try: ping dpg-d1g0cmali9vc73a392lg-a")
    print("   - The database might be behind a firewall or VPN")
    
    print("\n2. 🔑 DATABASE CREDENTIALS:")
    print("   - Verify the database credentials are correct")
    print("   - Check if the database user has proper permissions")
    print("   - The credentials might have expired or been rotated")
    
    print("\n3. 🖥️ DATABASE SERVER:")
    print("   - The database server might be down or restarting")
    print("   - Check the Render.com dashboard for database status")
    print("   - The database might be in maintenance mode")
    
    print("\n4. 🏠 LOCAL DEVELOPMENT OPTIONS:")
    print("   - Use a local PostgreSQL database for development")
    print("   - Use SQLite for local development (simpler setup)")
    print("   - Set up a local PostgreSQL instance")

def create_local_sqlite_config():
    """Create a local SQLite configuration for development"""
    print("\n" + "="*60)
    print("💡 LOCAL SQLITE SETUP (Recommended for development):")
    print("="*60)
    
    sqlite_config = '''# Local SQLite configuration for development
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

# Use SQLite for local development
SQLALCHEMY_DATABASE_URL = "sqlite:///./abm_sales.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, 
    connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()
'''
    
    print("Create a new file 'database_local.py' with this content:")
    print("-" * 40)
    print(sqlite_config)
    print("-" * 40)
    
    # Create the file
    with open("database_local.py", "w") as f:
        f.write(sqlite_config)
    
    print("✅ Created 'database_local.py' for local development")
    print("\nTo use local SQLite:")
    print("1. Replace 'from database import ...' with 'from database_local import ...' in main.py")
    print("2. Install SQLite support: pip install aiosqlite")
    print("3. Run your application locally")

if __name__ == "__main__":
    print("🚀 ABM SALES - Database Connection Diagnostic")
    print("=" * 50)
    
    # Test connections
    psycopg2_success = test_psycopg2_connection()
    sqlalchemy_success = test_sqlalchemy_connection()
    
    if not psycopg2_success and not sqlalchemy_success:
        suggest_solutions()
        create_local_sqlite_config()
    else:
        print("\n✅ Database connection is working!")
        print("The issue might be in your application code or environment setup.") 