import requests
import json
import os
from dotenv import load_dotenv

# We'll use a mock token or try to get one
# For testing purpose, we'll try to call create-intent WITHOUT a valid token first
# to see if we get 401, then we'll try to "force" a call if we can bypass auth for debug

BASE_URL = "http://127.0.0.1:8005"

def test_create_intent():
    # 1. Get a token (We'll try to log in)
    login_url = f"{BASE_URL}/login"
    login_data = {
        "username": "p13@p13.com",
        "password": "password123" # Guessing password or we'll check DB
    }
    
    print(f"Attempting to login...")
    # Since backend uses OAuth2PasswordRequestForm, we need to send as form data
    response = requests.post(login_url, data={"username": "p13@p13.com", "password": "password123"})
    
    if response.status_code == 200:
        token = response.json().get("access_token")
        print("Login SUCCESS!")
    else:
        print(f"Login FAILED: {response.status_code} {response.text}")
        return

    # 2. Call create-intent
    intent_url = f"{BASE_URL}/payments/create-intent"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {"amount": 43.75}
    
    print(f"Sending create-intent request...")
    response = requests.post(intent_url, headers=headers, json=payload)
    
    print(f"Response: {response.status_code}")
    print(f"Body: {response.text}")

if __name__ == "__main__":
    test_create_intent()
