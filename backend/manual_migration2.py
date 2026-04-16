import sqlite3

def run_migration():
    conn = sqlite3.connect('pharma.db')
    cursor = conn.cursor()
    
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN license_number VARCHAR")
        print("Column license_number added to users table.")
    except sqlite3.OperationalError as e:
        print("users.license_number ALREADY EXISTS or error:", e)

    try:
        cursor.execute("ALTER TABLE medicines ADD COLUMN requested_quantity INTEGER DEFAULT 0")
        print("Column requested_quantity added to medicines table.")
    except sqlite3.OperationalError as e:
        print("medicines.requested_quantity ALREADY EXISTS or error:", e)
        
    conn.commit()
    conn.close()

if __name__ == '__main__':
    run_migration()
