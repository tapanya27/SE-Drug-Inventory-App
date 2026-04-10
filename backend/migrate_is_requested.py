from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL").replace("postgresql://", "postgresql+psycopg://")

engine = create_engine(SQLALCHEMY_DATABASE_URL)

with engine.connect() as conn:
    print("Adding column 'is_requested' to table 'medicines'...")
    try:
        conn.execute(text("ALTER TABLE medicines ADD COLUMN is_requested BOOLEAN DEFAULT FALSE"))
        conn.commit()
        print("Column added successfully.")
    except Exception as e:
        print(f"Error (maybe column already exists?): {e}")

print("Migration complete.")
