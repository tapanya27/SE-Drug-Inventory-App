from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    # Reset ALL pharmacy users using the enum name
    conn.execute(text("UPDATE users SET is_verified = false WHERE role = 'PHARMACY' OR role = 'Pharmacy Store'"))
    conn.commit()
    print("Reset all pharmacy users to unverified")
    result = conn.execute(text("SELECT id, name, email, role, is_verified FROM users"))
    for row in result:
        print(row)
