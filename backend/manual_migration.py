from sqlalchemy import text
from database import engine

def migrate():
    with engine.connect() as conn:
        print("Migrating database...")
        conn.execute(text("ALTER TABLE medicines ADD COLUMN IF NOT EXISTS owner_id INTEGER REFERENCES users(id)"))
        conn.commit()
        print("Migration complete: owner_id column verified.")

if __name__ == "__main__":
    migrate()
