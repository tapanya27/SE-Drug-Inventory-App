import requests
import json
import sqlite3

BASE_URL = "http://127.0.0.1:8000"

def get_auth_token():
    # Attempt to find a pharmacy user for authentication
    # We'll try common emails if DB access fails
    emails = ["pharmacy@example.com", "central@pharmacy.com"]
    
    # Try to find from DB if possible (though we know it might fail due to Postgres)
    try:
        # This is just a fallback if they are using SQLite
        conn = sqlite3.connect("backend/pharma.db")
        cursor = conn.cursor()
        cursor.execute("SELECT email FROM users WHERE role = 'Pharmacy Store' LIMIT 1")
        row = cursor.fetchone()
        if row:
            emails.insert(0, row[0])
        conn.close()
    except:
        pass

    for email in emails:
        print(f"DEBUG: Attempting login with {email}")
        try:
            response = requests.post(f"{BASE_URL}/login", json={"email": email, "password": "Password123!"})
            if response.status_code == 200:
                return response.json()["access_token"]
        except:
            continue
    return None

def verify_filtering():
    token = get_auth_token()
    if not token:
        print("ERROR: Could not obtain auth token. Please ensure the backend is running and a pharmacy user exists.")
        return

    headers = {"Authorization": f"Bearer {token}"}
    
    # Test cases: different warehouse IDs
    for warehouse_id in [1, 2, 5]:
        print(f"\n--- Testing Warehouse ID: {warehouse_id} ---")
        url = f"{BASE_URL}/inventory?warehouse_id={warehouse_id}"
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            items = response.json()
            ids = set(item.get('owner_id') for item in items if item.get('owner_id') is not None)
            
            print(f"URL: {url}")
            print(f"Results: {len(items)} items")
            print(f"Found Owner IDs in results: {ids}")
            
            if len(ids) > 1:
                print("FAILURE: Multiple owner IDs found in results. Filtering failed.")
            elif len(ids) == 1 and list(ids)[0] != warehouse_id:
                print(f"FAILURE: Returned items for a different warehouse (Expected {warehouse_id}, got {list(ids)[0]}).")
            elif len(ids) == 0 and len(items) > 0:
                 print("FAILURE: Items returned with no owner_id but warehouse_id was specified.")
            else:
                print("SUCCESS: Filtering works correctly.")
        else:
            print(f"ERROR: {response.status_code} - {response.text}")

if __name__ == "__main__":
    verify_filtering()
