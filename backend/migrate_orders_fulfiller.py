from sqlalchemy import text
from database import engine

def migrate():
    with engine.connect() as conn:
        print("Migrating orders table...")
        # Add fulfiller_id column
        conn.execute(text("ALTER TABLE orders ADD COLUMN IF NOT EXISTS fulfiller_id INTEGER REFERENCES users(id)"))
        conn.commit()
        print("Migration complete: fulfiller_id column added to orders table.")

if __name__ == "__main__":
    migrate()
