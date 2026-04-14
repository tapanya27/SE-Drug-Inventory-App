import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
import sys

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

import models

# Load .env from backend folder
load_dotenv('backend/.env')

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    print("DATABASE_URL not found in .env")
    sys.exit(1)

# Fix for psycopg
DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def audit_inventory():
    db = SessionLocal()
    try:
        # Get all warehouses
        warehouses = db.query(models.User).filter(models.User.role == models.UserRole.WAREHOUSE).all()
        print(f"--- WAREHOUSES ({len(warehouses)}) ---")
        for w in warehouses:
            print(f"ID: {w.id}, Name: {w.name}")

        # Get all medicines
        medicines = db.query(models.Medicine).all()
        print(f"\n--- MEDICINES ({len(medicines)}) ---")
        for m in medicines:
            owner_name = "Global"
            if m.owner_id:
                owner = db.query(models.User).filter(models.User.id == m.owner_id).first()
                owner_name = owner.name if owner else f"Unknown ({m.owner_id})"
            print(f"ID: {m.id}, Name: {m.name}, Owner: {owner_name} (ID: {m.owner_id}), Stock: {m.stock}")

    finally:
        db.close()

if __name__ == "__main__":
    audit_inventory()
