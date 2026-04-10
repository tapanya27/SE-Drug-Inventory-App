from database import engine
from sqlalchemy import text

# Comprehensive list to handle both internal member names (ALL CAPS) 
# and human-readable values (Mixed Case)
ROLES = [
    "Pharmacy Store", "PHARMACY",
    "Warehouse", "WAREHOUSE",
    "Company", "COMPANY",
    "Admin", "ADMIN"
]

def fix_user_roles():
    print("Checking and fixing database roles (Comprehensive Sync)...")
    
    with engine.connect() as conn:
        try:
            result = conn.execute(text("SELECT enum_range(NULL::userrole)"))
            current_values = result.fetchone()[0]
            print(f"Existing values in DB: {current_values}")
        except Exception as e:
            print(f"Error checking current values: {e}")
            return

        conn.execute(text("COMMIT"))

        for role in ROLES:
            try:
                conn.execute(text(f"ALTER TYPE userrole ADD VALUE IF NOT EXISTS '{role}'"))
                print(f"Verified/Added: '{role}'")
            except Exception as e:
                print(f"Could not add {role}: {e}")
        
        conn.commit()
        
        result = conn.execute(text("SELECT enum_range(NULL::userrole)"))
        final_values = result.fetchone()[0]
        print(f"Final values in DB: {final_values}")

if __name__ == "__main__":
    fix_user_roles()
