from fastapi import FastAPI, Depends, HTTPException, status, Body, Request, UploadFile, File, Form, Query
from fastapi.staticfiles import StaticFiles
from jose import JWTError, jwt
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import timedelta, datetime
from database import engine, get_db, Base
import models, schemas, crud, auth_utils
from verification_service import LicenseVerifier
import stripe
import os
import uuid
import json
from dotenv import load_dotenv
load_dotenv()

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Pharma Supply System API")

# Stripe Configuration
# (Key now assigned dynamically in request handlers to ensure sync with .env)

from fastapi.middleware.cors import CORSMiddleware

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, auth_utils.SECRET_KEY, algorithms=[auth_utils.ALGORITHM])
        if payload.get("type") != "access":
            raise credentials_exception
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = crud.get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
    return user

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    auth_header = request.headers.get("Authorization", "No Token")
    token_preview = auth_header[:15] + "..." if len(auth_header) > 15 else auth_header
    print(f"DEBUG: Incoming Request: {request.method} {request.url} | Params: {request.query_params} | Auth: {token_preview}")
    response = await call_next(request)
    print(f"DEBUG: Response Status: {response.status_code}")
    return response

@app.get("/test_query")
def test_query(warehouse_id: Optional[int] = Query(None)):
    return {"received_warehouse_id": warehouse_id}

# --- Inventory Endpoints (Moved to Top for Priority) ---

def _get_inventory_internal(
    request: Request,
    warehouse_id: Optional[int],
    mode: Optional[str],
    skip: int,
    limit: int,
    db: Session,
    current_user: models.User
):
    user_role = str(current_user.role).lower()
    
    # 1. Company Role
    if "company" in user_role:
        results = db.query(models.Medicine).filter(
            models.Medicine.is_requested == True,
            models.Medicine.owner_id != None
        ).all()
        return [schemas.MedicineResponse.from_orm(med) for med in results]
    
    # 2. Pharmacy Role
    if "pharmacy" in user_role:
        # If warehouse_id is specified, we are browsing that specific warehouse
        if warehouse_id is not None and warehouse_id > 0:
             return crud.get_medicines(db, owner_id=int(warehouse_id), skip=skip, limit=limit)
        
        # If mode is marketplace, show all warehouse items
        if mode == "marketplace":
             return crud.get_marketplace_medicines(db, skip=skip, limit=limit)
        
        # Default for Pharmacy: Show their OWN stock
        return crud.get_medicines(db, owner_id=current_user.id, skip=skip, limit=limit)

    # 3. Warehouse Role
    if "warehouse" in user_role:
        return crud.get_medicines(db, owner_id=current_user.id, skip=skip, limit=limit)
        
    # Default Fallback (General Catalog for Admin)
    return crud.get_catalog(db)

@app.get("/inventory", response_model=List[schemas.MedicineResponse])
async def read_inventory(
    request: Request,
    warehouse_id: Optional[int] = Query(None),
    mode: Optional[str] = Query(None), # 'personal' or 'marketplace'
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """General inventory endpoint with role-based filtering."""
    return _get_inventory_internal(request, warehouse_id, mode, skip, limit, db, current_user)

@app.get("/inventory/warehouse/{warehouse_id}", response_model=List[schemas.MedicineResponse])
async def read_inventory_by_warehouse(
    request: Request,
    warehouse_id: int,
    skip: int = 0, 
    limit: int = 100, 
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_current_user)
):
    """Specific warehouse browsing."""
    return _get_inventory_internal(request, warehouse_id, None, skip, limit, db, current_user)

# --- Auth Endpoints ---

@app.post("/signup", response_model=schemas.UserResponse)
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    if user.role == models.UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin accounts cannot be created via signup")
    new_user = crud.create_user(db=db, user=user)
    
    # Standardized Pharmacy Role Check (Case-insensitive + Value check)
    user_role_str = str(new_user.role).lower()
    is_pharmacy = "pharmacy" in user_role_str or new_user.role == models.UserRole.PHARMACY
    
    # Auto-verify non-pharmacy users
    if not is_pharmacy:
        print(f"DEBUG: Auto-verifying non-pharmacy user {new_user.id} (Role: {new_user.role})")
        new_user.is_verified = True
        db.commit()
    else:
        print(f"DEBUG: Pharmacy user {new_user.id} registered. Verification REQUIRED.")
        
    return new_user

@app.post("/login")
async def login(request: Request, db: Session = Depends(get_db)):
    # 1. Get the raw body
    body_bytes = await request.body()
    content_type = request.headers.get("Content-Type", "")
    
    login_data = {}
    
    # 2. Parse based on content type
    if "application/json" in content_type:
        try:
            login_data = await request.json()
        except:
            pass
    else:
        # Fallback: try to parse as form data or just raw string
        from urllib.parse import parse_qs
        parsed = parse_qs(body_bytes.decode())
        login_data = {k: v[0] for k, v in parsed.items()}

    # 3. Handle both 'email' and 'username' keys
    email = login_data.get("email") or login_data.get("username")
    password = login_data.get("password")
    
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email/Username and Password are required")
        
    user = crud.get_user_by_email(db, email=email)
    if not user or not auth_utils.verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=auth_utils.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = auth_utils.create_access_token(
        data={"sub": user.email, "role": user.role}, expires_delta=access_token_expires
    )
    refresh_token = auth_utils.create_refresh_token(
        data={"sub": user.email}
    )
    return {
        "access_token": access_token, 
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "role": user.role,
        "is_verified": user.is_verified
    }

@app.post("/refresh")
async def refresh_token(refresh_token: str = Body(..., embed=True), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate refresh token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(refresh_token, auth_utils.SECRET_KEY, algorithms=[auth_utils.ALGORITHM])
        if payload.get("type") != "refresh":
            raise credentials_exception
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = crud.get_user_by_email(db, email=email)
    if user is None:
        raise credentials_exception
        
    access_token = auth_utils.create_access_token(
        data={"sub": user.email, "role": user.role}
    )
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }



@app.put("/inventory/{medicine_id}/request")
def request_medicine_stock(medicine_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.WAREHOUSE:
        raise HTTPException(status_code=403, detail="Not authorized")
    db_medicine = crud.request_stock(db, medicine_id=medicine_id)
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return db_medicine

@app.put("/inventory/{medicine_id}/replenish")
def replenish_medicine_stock(medicine_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.COMPANY:
        raise HTTPException(status_code=403, detail="Only Company can replenish stock")
    db_medicine = crud.replenish_stock(db, medicine_id=medicine_id)
    if db_medicine is None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return db_medicine

@app.get("/analytics/demand")
def demand_prediction(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Warehouse and Company can see demand spikes
    if current_user.role not in [models.UserRole.WAREHOUSE, models.UserRole.COMPANY]:
        raise HTTPException(status_code=403, detail="Not authorized")
    return crud.get_demand_prediction(db)

# --- Order Endpoints ---

@app.post("/orders", response_model=schemas.OrderResponse)
def create_order(order: schemas.OrderCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    return crud.create_order(db=db, order=order, user_id=current_user.id)

@app.get("/inventory/catalog", response_model=List[schemas.MedicineResponse])
def read_catalog(db: Session = Depends(get_db)):
    return crud.get_catalog(db)

@app.get("/warehouses", response_model=List[schemas.UserResponse])
def list_warehouses(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    """Publicly list all active warehouses for Pharmacies to order from."""
    return db.query(models.User).filter(models.User.role == models.UserRole.WAREHOUSE).all()


@app.get("/inventory/low-stock", response_model=List[schemas.MedicineResponse])
def read_low_stock(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # Company can see all low-stock warehouse items
    results = db.query(models.Medicine).filter(
        models.Medicine.stock <= models.Medicine.threshold,
        models.Medicine.owner_id != None
    ).all()
    return [schemas.MedicineResponse.from_orm(med) for med in results]

@app.post("/inventory/add/{medicine_id}", response_model=schemas.MedicineResponse)
def add_to_warehouse_inventory(medicine_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.WAREHOUSE:
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Only warehouses can add products from catalog")
    
    db_med = crud.add_to_inventory(db, medicine_id=medicine_id, user_id=current_user.id)
    if not db_med:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Catalog item not found")
    return db_med

@app.get("/orders", response_model=List[schemas.OrderResponse])
def read_orders(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # If the user is a Pharmacy, only show their own orders
    if current_user.role == models.UserRole.PHARMACY:
        user_orders = crud.get_user_orders(db, user_id=current_user.id)
        output = []
        for o in user_orders:
            res = schemas.OrderResponse.from_orm(o)
            res.user_name = current_user.name
            res.user_role = current_user.role
            res.warehouse_id = o.fulfiller_id
            res.warehouse_name = o.fulfiller.name if o.fulfiller else "Unknown"
            output.append(res)
        return output
        
    # If the user is a Warehouse, only show orders assigned to them
    if current_user.role == models.UserRole.WAREHOUSE:
        return crud.get_all_orders(db, fulfiller_id=current_user.id)
        
    # Admin/Company see everything
    return crud.get_all_orders(db)


@app.get("/warehouse/stats")
def warehouse_stats(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.WAREHOUSE:
        raise HTTPException(status_code=403, detail="Not authorized")
    return crud.get_warehouse_stats(db, owner_id=current_user.id)

@app.get("/admin/users")
def list_users(db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    if current_user.role != models.UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin access required")
    return db.query(models.User).all()

@app.put("/orders/{order_id}/status")
async def update_status(order_id: int, request: Request, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    body_bytes = await request.body()
    body_str = body_bytes.decode().strip()
    print(f"DEBUG: Status Update Request for Order {order_id} by User {current_user.id}: {body_str}")
    
    new_status = None
    try:
        data = await request.json()
        if isinstance(data, dict):
            new_status = data.get("status")
        elif isinstance(data, str):
            new_status = data
    except:
        from urllib.parse import parse_qs
        parsed = parse_qs(body_str)
        new_status = parsed.get("status", [None])[0]

    if not new_status:
        # Last ditch effort: try cleaning the raw string if it looks like "Dispatched"
        new_status = body_str.strip('"\'')
        
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")
        
    updated_order, warnings = crud.update_order_status(db=db, order_id=order_id, status=new_status, fulfiller_id=current_user.id)
    if not updated_order:
        raise HTTPException(status_code=404, detail="Order not found")
        
    return {"order": updated_order, "warnings": warnings}


# Initial Seed Route (for testing)
@app.post("/seed")
def seed_data(db: Session = Depends(get_db)):
    existing_medicines = {m.name: m for m in db.query(models.Medicine).all()}
    
    medicines_to_seed = [
        {"name": "Paracetamol 500mg", "price": 5.5, "stock": 1000, "threshold": 200},
        {"name": "Amoxicillin 250mg", "price": 12.0, "stock": 500, "threshold": 100},
        {"name": "Ibuprofen 400mg", "price": 8.75, "stock": 750, "threshold": 150},
    ]
    
    added_count = 0
    for med_data in medicines_to_seed:
        if med_data["name"] not in existing_medicines:
            new_med = models.Medicine(**med_data)
            db.add(new_med)
            added_count += 1
            
    db.commit()
    return {"message": f"Database seed check complete. Added {added_count} new medicines."}

@app.delete("/orders/{order_id}/cancel")
def cancel_order(order_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    db_order = db.query(models.Order).filter(models.Order.id == order_id).first()
    if not db_order:
        raise HTTPException(status_code=404, detail="Order not found")
    if db_order.user_id != current_user.id and current_user.role != models.UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Not authorized to cancel this order")
    if db_order.status != models.OrderStatus.PROCESSING:
        raise HTTPException(status_code=400, detail="Only processing orders can be cancelled")
    
    db.delete(db_order)
    db.commit()
    return {"message": "Order cancelled successfully"}

@app.post("/payments/create-intent")
async def create_payment_intent(request: Request, current_user: models.User = Depends(get_current_user)):
    try:
        # DYNAMIC KEY LOADING
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")
        print(f"DEBUG: Initializing Stripe with key: {stripe.api_key[:15]}...")
        
        data = await request.json()
        # Amount should be in cents (e.g., $10.00 -> 1000)
        amount = int(float(data.get("amount")) * 100)
        
        intent = stripe.PaymentIntent.create(
            amount=amount,
            currency="usd",
            automatic_payment_methods={"enabled": True},
            metadata={"user_id": current_user.id}
        )
        
        return {
            "paymentIntent": intent.client_secret,
            "publishableKey": os.getenv("STRIPE_PUBLISHABLE_KEY", "")
        }
    except Exception as e:
        print(f"ERROR: PaymentIntent failed: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))


# --- Document Verification Endpoints (Pharmacy Only) ---

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png"}
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5 MB

def validate_document(filename: str, file_size: int):
    """Auto-validate document based on file type and size."""
    ext = os.path.splitext(filename)[1].lower()
    errors = []
    
    if ext not in ALLOWED_EXTENSIONS:
        errors.append(f"Invalid file type '{ext}'. Allowed: PDF, JPG, PNG.")
    if file_size > MAX_FILE_SIZE:
        errors.append(f"File too large ({file_size // 1024}KB). Max: 5MB.")
    if file_size < 1024:
        errors.append("File too small. Please upload a valid document.")
    
    return errors

@app.post("/documents/upload", response_model=schemas.DocumentResponse)
async def upload_document(
    doc_type: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Upload a verification document (Pharmacy users only)."""
    print("\n" + "="*60)
    print(">>> V2 SECURITY ENGINE ONLINE: ENTERING UPLOAD ENDPOINT <<<")
    print("="*60 + "\n")
    if current_user.role != models.UserRole.PHARMACY:
        raise HTTPException(status_code=403, detail="Document verification is only required for Pharmacy accounts.")
    
    if current_user.is_verified:
        raise HTTPException(status_code=400, detail="Your account is already verified.")
    
    # Read file content
    content = await file.read()
    file_size = len(content)
    
    # Validate the document
    validation_errors = validate_document(file.filename, file_size)
    if validation_errors:
        raise HTTPException(status_code=400, detail="; ".join(validation_errors))
    
    # Save file with unique name
    ext = os.path.splitext(file.filename)[1].lower()
    unique_filename = f"{current_user.id}_{uuid.uuid4().hex[:8]}{ext}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)
    
    with open(file_path, "wb") as f:
        f.write(content)
    
    # ========== AI VERIFICATION ==========
    verifier = LicenseVerifier()
    ai_result = verifier.verify(file_path, file.filename, file_size)
    
    print("\n" + "!"*60)
    print(">>> V3 CANARY PULSE: SECURITY ENGINE ACTIVATED <<<")
    print("!"*60 + "\n")
    print(f"[AI] Verification Result: {json.dumps(ai_result, indent=2)}")
    
    # Map AI status to DocStatus with strictly enforced score checks
    ai_status = ai_result["status"].strip().upper()
    ai_score = int(ai_result.get("confidence_score") or 0) # Force int, default 0
    
    print(f"[AI] Decision Logic -> Status: {ai_status}, Score: {ai_score} (Type: {type(ai_score)})")
    
    # FORCED FAIL-SAFE: Any score below 85 CANNOT be fully Approved for Pharmacy
    if ai_status == "APPROVED" and ai_score >= 85:
        doc_status = models.DocStatus.APPROVED
    elif ai_status == "REJECTED" or ai_score < 50:
        doc_status = models.DocStatus.REJECTED
        if ai_score < 50:
            ai_result["issues"].append(f"Confidence score {ai_score} is too low for security clearance.")
    else:  # REVIEW (50-84)
        doc_status = models.DocStatus.PENDING
    
    # Build rejection reason if applicable
    rejection_reason = None
    if ai_result["issues"]:
        rejection_reason = "; ".join(ai_result["issues"])
    
    doc = models.Document(
        user_id=current_user.id,
        filename=file.filename,
        file_path=unique_filename,
        doc_type=doc_type,
        status=doc_status,
        ai_score=ai_result["confidence_score"],
        extracted_data=json.dumps(ai_result["extracted_data"]),
        verification_issues=json.dumps(ai_result["issues"]),
        rejection_reason=rejection_reason,
        reviewed_at=datetime.utcnow()
    )
    db.add(doc)
    
    print(f"[AI] FINAL GUARD CHECK -> Status: {ai_status}, Score: {ai_score}")
    
    # Only auto-verify if AI APPROVED AND score is high enough (Zero-Trust Guard)
    if doc_status == models.DocStatus.APPROVED:
        print(f"[AI] AUTO-APPROVING USER {current_user.id} (Score: {ai_score})")
        current_user.is_verified = True
    else:
        # PENDING or REJECTED result revokes/prevents auto-verification
        print(f"[AI] REVOKING/DENYING VERIFICATION FOR USER {current_user.id} (Status: {doc_status})")
        current_user.is_verified = False
    
    db.add(current_user) # Explicitly add to session for tracking
    db.commit()
    db.refresh(doc)
    db.refresh(current_user)
    
    return doc

@app.get("/documents/my", response_model=List[schemas.DocumentResponse])
def get_my_documents(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Get all documents uploaded by the current user."""
    docs = db.query(models.Document).filter(models.Document.user_id == current_user.id).order_by(models.Document.uploaded_at.desc()).all()
    return docs

@app.get("/documents/pending", response_model=List[schemas.DocumentResponse])
def get_pending_documents(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Admin only: Get all pending documents for review."""
    if current_user.role != models.UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Admin access required.")
    docs = db.query(models.Document).filter(models.Document.status == models.DocStatus.PENDING).all()
    return docs

@app.get("/me/verification-status")
def get_verification_status(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """Check the current user's verification status with self-healing audit."""
    # SELF-HEALING AUDIT: If pharmacy is verified but has no approved docs, reset them
    if current_user.role == models.UserRole.PHARMACY and current_user.is_verified:
        has_approved = db.query(models.Document).filter(
            models.Document.user_id == current_user.id,
            models.Document.status == models.DocStatus.APPROVED
        ).first() is not None
        
        if not has_approved:
            print(f"CRITICAL: Found verified pharmacy {current_user.id} with NO approved docs. Resetting.")
            current_user.is_verified = False
            db.commit()
            db.refresh(current_user)

    return {
        "is_verified": current_user.is_verified,
        "role": current_user.role,
        "requires_verification": current_user.role == models.UserRole.PHARMACY,
        "canary_version": "V3-ACTIVE-HEALED"
    }
