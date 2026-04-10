"""Add is_verified to users and create documents table."""
import os, sys
sys.path.append(os.path.dirname(__file__))

from database import engine
from sqlalchemy import text

def migrate():
    with engine.connect() as conn:
        # Add is_verified column to users
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT false"))
            conn.commit()
            print("[OK] Added is_verified column to users")
        except Exception as e:
            conn.rollback()
            print(f"[SKIP] is_verified column: {e}")

        # Create DocStatus enum
        try:
            conn.execute(text("CREATE TYPE docstatus AS ENUM ('Pending', 'Approved', 'Rejected')"))
            conn.commit()
            print("[OK] Created docstatus enum")
        except Exception as e:
            conn.rollback()
            print(f"[SKIP] docstatus enum: {e}")

        # Create documents table
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS documents (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER REFERENCES users(id),
                    filename VARCHAR,
                    file_path VARCHAR,
                    doc_type VARCHAR,
                    status docstatus DEFAULT 'Pending',
                    rejection_reason VARCHAR,
                    uploaded_at TIMESTAMP DEFAULT NOW(),
                    reviewed_at TIMESTAMP
                )
            """))
            conn.commit()
            print("[OK] Created documents table")
        except Exception as e:
            conn.rollback()
            print(f"[SKIP] documents table: {e}")

        # Set existing non-pharmacy users as verified
        try:
            conn.execute(text("UPDATE users SET is_verified = true WHERE role != 'Pharmacy Store'"))
            conn.commit()
            print("[OK] Auto-verified all non-pharmacy users")
        except Exception as e:
            conn.rollback()
            print(f"[SKIP] auto-verify: {e}")

    print("\nMigration complete!")

if __name__ == "__main__":
    migrate()
