from database import SessionLocal
from models import Medicine

db = SessionLocal()

# Delete records with ID 4, 5
db.query(Medicine).filter(Medicine.id.in_([4, 5])).delete(synchronize_session=False)

db.commit()

print("Cleaned up duplicated medicines.")
