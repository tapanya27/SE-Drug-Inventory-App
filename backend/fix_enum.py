from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    # Check current enum values
    result = conn.execute(text("SELECT enum_range(NULL::userrole)"))
    print("Current enum values:", result.fetchone())
    
    # Try adding if missing
    try:
        conn.execute(text("COMMIT"))  # End any open transaction
    except:
        pass
    
    try:
        conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'Company'"))
        print("Added 'Company'")
    except Exception as e:
        print(f"Company add result: {e}")
    
    try:
        conn.execute(text("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'Admin'"))
        print("Added 'Admin'")
    except Exception as e:
        print(f"Admin add result: {e}")
    
    conn.commit()
    
    # Verify
    result = conn.execute(text("SELECT enum_range(NULL::userrole)"))
    print("Updated enum values:", result.fetchone())
