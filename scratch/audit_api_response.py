import requests
import json

BASE_URL = "http://127.0.0.1:8000"

def test_api_inventory():
    # 1. Login as a Pharmacy (assuming this user exists and is a pharmacy)
    # I'll try to find a pharmacy user first
    login_url = f"{BASE_URL}/login"
    # This is a guess based on common test users or I need to check the DB
    # Let's try to find an actual pharmacy user from the DB first
    import sqlite3
    db_path = "backend/pharma.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("SELECT email FROM users WHERE role = 'Pharmacy Store' LIMIT 1")
    row = cursor.fetchone()
    conn.close()
    
    if not row:
        print("No pharmacy user found in DB.")
        return
        
    email = row[0]
    print(f"Testing with pharmacy user: {email}")
    
    response = requests.post(login_url, json={"email": email, "password": "Password123!"})
    if response.status_code != 200:
        print(f"Login failed: {response.text}")
        return
        
    token = response.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Fetch inventory for Warehouse 5
    inventory_url = f"{BASE_URL}/inventory?warehouse_id=5"
    response = requests.get(inventory_url, headers=headers)
    
    print(f"GET {inventory_url} Status: {response.status_code}")
    if response.status_code == 200:
        items = response.json()
        print(f"Total items returned: {len(items)}")
        for item in items[:10]:
            print(f"Item: {item['name']}, Owner ID: {item['owner_id']}")
    else:
        print(f"Error: {response.text}")

if __name__ == "__main__":
    test_api_inventory()
