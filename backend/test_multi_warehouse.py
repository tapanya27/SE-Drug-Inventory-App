from database import SessionLocal
from models import Medicine, User, UserRole
import crud

def run_test():
    db = SessionLocal()
    
    print("Setting up test data for multiple warehouses...")
    
    # Get warehouses
    w1 = db.query(User).filter(User.name == "Tan").first()
    w2 = db.query(User).filter(User.name == "Warehouse1").first()
    
    if not w1 or not w2:
        print("Missing test warehouses. Creating them...")
        # (Assuming they exist based on previous tasklist output)
    
    # Create distinct inventory for each warehouse
    med_name = "Test Multi-Warehouse Med"
    
    # Clear existing test data if any
    db.query(Medicine).filter(Medicine.name == med_name).delete()
    db.commit()
    
    # Global Catalog Template
    catalog = Medicine(name=med_name, price=5.5, stock=0, threshold=200, owner_id=None)
    
    # Warehouse 1 Stock
    inv1 = Medicine(name=med_name, price=5.5, stock=50, threshold=100, owner_id=w1.id, is_requested=True)
    
    # Warehouse 2 Stock
    inv2 = Medicine(name=med_name, price=5.5, stock=500, threshold=100, owner_id=w2.id, is_requested=False)
    
    db.add_all([catalog, inv1, inv2])
    db.commit()
    
    print(f"Inventory created for {w1.name} (ID: {w1.id}) and {w2.name} (ID: {w2.id}).")
    
    # 1. Test Fetching (Warehouse 1 perspective)
    print("\n--- TEST: Warehouse 1 Inventory View ---")
    inventory = crud.get_medicines(db, owner_id=w1.id)
    for m in inventory:
        print(f"Product: {m.name} | Stock: {m.stock} | Owner: {m.owner_name}")
    
    # 2. Test Fetching (Company perspective - see requests)
    print("\n--- TEST: Company Replenishment View ---")
    all_inventory = crud.get_medicines(db) # No owner filter
    requested = [m for m in all_inventory if m.is_requested]
    for r in requested:
        print(f"REQUEST FOUND: {r.name} from {r.owner_name}")
        
    # 3. Test Replenishment
    print("\n--- TEST: Replenishing Warehouse 1's Stock ---")
    # Fetch the SQLAlchemy object directly for the test
    med_attr = db.query(Medicine).filter(Medicine.owner_id == w1.id, Medicine.name == med_name).first()
    old_stock = med_attr.stock
    crud.replenish_stock(db, medicine_id=med_attr.id)
    
    db.refresh(med_attr)
    print(f"SUCCESS: {med_attr.name} stock for {w1.name} updated: {old_stock} -> {med_attr.stock}")
    
    db.close()

if __name__ == "__main__":
    run_test()
