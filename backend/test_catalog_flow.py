from database import SessionLocal
from models import Medicine, User
import crud

def run_test():
    db = SessionLocal()
    
    # 1. New Warehouse (Empty initially)
    # Let's use ID 6 which was a duplicate Tanaya
    w_id = 6
    print(f"Testing for Warehouse ID: {w_id}")
    
    # Ensure they have NO medicines
    db.query(Medicine).filter(Medicine.owner_id == w_id).delete()
    db.commit()
    
    print("\n--- STEP 1: Verify Initial Inventory is Empty ---")
    inv = crud.get_medicines(db, owner_id=w_id)
    print(f"Inventory count: {len(inv)}")
    if len(inv) == 0:
        print("SUCCESS: New warehouse starts with empty inventory.")
    
    # 2. Browse Catalog
    print("\n--- STEP 2: Browse Catalog ---")
    catalog = crud.get_catalog(db)
    print(f"Catalog items found: {[m.name for m in catalog]}")
    
    # 3. Add item from catalog
    print("\n--- STEP 3: Add 'Paracetamol 500mg' to Inventory ---")
    paracetamol_template = [m for m in catalog if m.name == "Paracetamol 500mg"][0]
    crud.add_to_inventory(db, medicine_id=paracetamol_template.id, user_id=w_id)
    
    # 4. Final Verification
    print("\n--- STEP 4: Verify Isolated Inventory ---")
    new_inv = crud.get_medicines(db, owner_id=w_id)
    print(f"Local inventory count: {len(new_inv)}")
    for m in new_inv:
        print(f"Product in my warehouse: {m.name} | Stock: {m.stock}")
        
    db.close()

if __name__ == "__main__":
    run_test()
