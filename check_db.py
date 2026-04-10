from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys
import os

# Add the current directory to sys.path to import models
sys.path.append(os.getcwd())
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from backend import models

DATABASE_URL = "sqlite:///./backend/pharma.db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def check_orders():
    db = SessionLocal()
    try:
        users = db.query(models.User).all()
        print("--- USERS ---")
        for u in users:
            print(f"ID: {u.id}, Email: {u.email}, Role: {u.role}")
            
        orders = db.query(models.Order).all()
        print("\n--- ORDERS ---")
        if not orders:
            print("No orders found in database.")
        for o in orders:
            print(f"Order ID: {o.id}, User ID: {o.user_id}, Status: {o.status}, Amount: {o.total_amount}")
    finally:
        db.close()

if __name__ == "__main__":
    check_orders()
