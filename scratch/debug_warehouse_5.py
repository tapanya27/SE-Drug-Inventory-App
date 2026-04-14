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

def check_warehouse_5():
    db = SessionLocal()
    try:
        # Find Warehouse 5
        warehouse_5 = db.query(models.User).filter(models.User.name.ilike('%Warehouse5%')).first()
        if not warehouse_5:
            print("Warehouse 5 not found by name 'Warehouse5'")
            # Let's list all warehouses
            warehouses = db.query(models.User).filter(models.User.role == models.UserRole.WAREHOUSE).all()
            print("Available Warehouses:")
            for w in warehouses:
                print(f"ID: {w.id}, Name: {w.name}, Role: {w.role}")
        else:
            print(f"Found Warehouse: ID: {warehouse_5.id}, Name: {warehouse_5.name}")
            
            # Check inventory for this warehouse
            inventory = db.query(models.Medicine).filter(models.Medicine.owner_id == warehouse_5.id).all()
            print(f"\nInventory for Warehouse {warehouse_5.id}:")
            if not inventory:
                print("No inventory found for this warehouse in the database.")
            else:
                for item in inventory:
                    print(f"ID: {item.id}, Name: {item.name}, Price: {item.price}, Stock: {item.stock}")
                    
        # Also check global medicines (owner_id is NULL)
        global_medicines = db.query(models.Medicine).filter(models.Medicine.owner_id == None).all()
        print("\nGlobal Catalog Medicines:")
        for item in global_medicines:
            print(f"ID: {item.id}, Name: {item.name}, Stock: {item.stock}")

    finally:
        db.close()

if __name__ == "__main__":
    check_warehouse_5()
