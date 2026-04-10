from database import SessionLocal
from models import Medicine, OrderItem

db = SessionLocal()

# List all medicines
medicines = db.query(Medicine).all()
medicine_names = {}
to_delete = []

# ID 2 is the one that has 84 stock for Amoxicillin, keep it.
# ID 1 is the one for Paracetamol, keep it.
# ID 3 is the one for Ibuprofen, keep it.

for med in medicines:
    if med.name not in medicine_names:
        medicine_names[med.name] = med.id
    else:
        # We found a duplicate. 
        # But we must be careful not to delete an ID referenced in OrderItems.
        # Let's check if this medicine has order items.
        has_orders = db.query(OrderItem).filter(OrderItem.medicine_id == med.id).first() is not None
        if not has_orders:
            to_delete.append(med.id)
        else:
             # if the FIRST one we found doesn't have orders, but the DUPLICATE does,
             # we should probably have swapped them.
             # In our specific case, I know ID 2 has orders (from my check_db_state output).
             # ID 1 has orders. ID 3 has orders. ID 6 has orders.
             pass

# Wait, my check_db_state output showed:
# ID: 1, Paracetamol, Stock 994
# ID: 3, Ibuprofen, Stock 747
# ID: 6, Ibuprofen, Stock 742 (This one HAS an order! Order ID 3)
# ID: 2, Amoxicillin, Stock 84 (This one HAS an order! Order ID 4)

# Since ID 6 has an order, I shouldn't just delete it.
# But for Amoxicillin, there's only ID 2 left now.

print(f"Current Ibuprofen entries: ID 3 (Stock {db.get(Medicine, 3).stock}), ID 6 (Stock {db.get(Medicine, 6).stock})")

# Let's just leave it as is for now since they both have orders, 
# or I could merge them but that's overkill.
# The user's main complaint was Amoxicillin showing 500 when it should be 84.
# I already deleted the Amoxicillin duplicate (ID 5: 500 stock).

db.close()
