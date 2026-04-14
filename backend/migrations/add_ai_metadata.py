import os
import psycopg
from dotenv import load_dotenv

load_dotenv()

# Build connection string
# Note: psycopg3 uses a different format, but we can use the environment variable
db_url = os.getenv("DATABASE_URL")
if not db_url:
    print("Error: DATABASE_URL not found in .env")
    exit(1)

# Connect to PostgreSQL
try:
    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            # Check if columns exist
            cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'documents'")
            existing_columns = [row[0] for row in cur.fetchall()]
            
            print(f"Existing columns: {existing_columns}")
            
            # Add ai_score
            if 'ai_score' not in existing_columns:
                print("Adding ai_score column...")
                cur.execute("ALTER TABLE documents ADD COLUMN ai_score INTEGER")
            
            # Add extracted_data
            if 'extracted_data' not in existing_columns:
                print("Adding extracted_data column...")
                cur.execute("ALTER TABLE documents ADD COLUMN extracted_data TEXT")
                
            # Add verification_issues
            if 'verification_issues' not in existing_columns:
                print("Adding verification_issues column...")
                cur.execute("ALTER TABLE documents ADD COLUMN verification_issues TEXT")
            
            conn.commit()
            print("Migration successful!")
except Exception as e:
    print(f"Migration failed: {e}")
