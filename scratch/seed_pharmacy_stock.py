import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

import models

load_dotenv('backend/.env')
db_url = os.getenv("DATABASE_URL").replace("postgresql://", "postgresql+psycopg://")
engine = create_engine(db_url)
SessionLocal = sessionmaker(bind=engine)

def seed_pharmacy_stock(user_id):
    db = SessionLocal()
    try:
        # Check if user exists
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if not user:
            print(f"User {user_id} not found.")
            return

        print(f"Seeding stock for {user.name} (Role: {user.role})")
        
        medicines = [
            {"name": "Paracetamol 500mg", "price": 5.5, "stock": 50, "threshold": 20},
            {"name": "Ibuprofen 400mg", "price": 8.75, "stock": 30, "threshold": 15},
            {"name": "Amoxicillin 250mg", "price": 12.0, "stock": 10, "threshold": 12},
        ]

        for med_data in medicines:
            # Check if exists
            existing = db.query(models.Medicine).filter(
                models.Medicine.name == med_data["name"],
                models.Medicine.owner_id == user_id
            ).first()
            
            if not existing:
                new_med = models.Medicine(**med_data, owner_id=user_id)
                db.add(new_med)
            else:
                existing.stock = med_data["stock"]
                existing.threshold = med_data["threshold"]

        db.commit()
        print("Stock seeded successfully.")
    finally:
        db.close()

if __name__ == "__main__":
    seed_pharmacy_stock(29)
