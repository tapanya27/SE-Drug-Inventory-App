from database import engine
from sqlalchemy import text

def add_cols():
    with engine.begin() as conn:
        try:
            conn.execute(text("ALTER TABLE users ADD COLUMN license_number VARCHAR"))
            print("Added license_number to users")
        except Exception as e:
            print("Users:", e)
        
        try:
            conn.execute(text("ALTER TABLE medicines ADD COLUMN requested_quantity INTEGER DEFAULT 0"))
            print("Added requested_quantity to medicines")
        except Exception as e:
            print("Medicines:", e)

if __name__ == "__main__":
    add_cols()
