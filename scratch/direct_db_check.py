import sqlite3
import os

db_path = "backend/pharma.db"
if not os.path.exists(db_path):
    print(f"Database {db_path} not found.")
else:
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    print("--- USERS ---")
    cursor.execute("SELECT id, name, role FROM users")
    for row in cursor.fetchall():
        print(row)
        
    print("\n--- MEDICINES ---")
    cursor.execute("SELECT id, name, owner_id, stock FROM medicines")
    for row in cursor.fetchall():
        print(row)
    
    conn.close()
