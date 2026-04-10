from fastapi import FastAPI, Depends, HTTPException, status, Body, Request, UploadFile, File, Form
from fastapi.staticfiles import StaticFiles
from jose import JWTError, jwt
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import List
from datetime import timedelta, datetime
from database import engine, get_db, Base
import models, schemas, crud, auth_utils
import stripe
import os
import uuid

# Create tables
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Pharma Supply System API")

# Stripe Configuration
stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")

from fastapi.middleware.cors import CORSMiddleware

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

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
    print(f"DEBUG: Incoming Request: {request.method} {request.url} | Auth: {token_preview}")
    response = await call_next(request)
    print(f"DEBUG: Response Status: {response.status_code}")
    return response

# --- Auth Endpoints ---

@app.post("/signup", response_model=schemas.UserResponse)
def signup(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = crud.get_user_by_email(db, email=user.email)
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    new_user = crud.create_user(db=db, user=user)
    # Auto-verify non-pharmacy users
    if new_user.role != models.UserRole.PHARMACY:
        new_user.is_verified = True
        db.commit()
        db.refresh(new_user)
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

# --- Inventory Endpoints ---

@app.get("/inventory", response_model=List[schemas.MedicineResponse])
def read_inventory(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_user)):
    # If the user is a Company, show all items that have is_requested=True across the whole system
    # BUT EXCLUDE global catalog items (owner_id IS NOT NULL)
    if current_user.role == models.UserRole.COMPANY:
        results = db.query(models.Medicine).filter(
            models.Medicine.is_requested == True,
            models.Medicine.owner_id != None
        ).all()
        return [schemas.MedicineResponse.from_orm(med) for med in results]
    
    # If the user is a Warehouse, show their specific inventory
    # If the user is a Pharmacy, show all warehouse-owned medicines to search FROM
    owner_id = current_user.id if current_user.role == models.UserRole.WAREHOUSE else None
    show_all = current_user.role == models.UserRole.PHARMACY
    return crud.get_medicines(db, owner_id=owner_id, show_all_warehouses=show_all, skip=skip, limit=limit)

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
            output.append(res)
        return output
    # Warehouse and Admin/Company see everything with requester info
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
    
    # Auto-approve if file passes validation
    doc = models.Document(
        user_id=current_user.id,
        filename=file.filename,
        file_path=unique_filename,
        doc_type=doc_type,
        status=models.DocStatus.APPROVED,
        reviewed_at=datetime.utcnow()
    )
    db.add(doc)
    
    # Mark user as verified
    current_user.is_verified = True
    db.commit()
    db.refresh(doc)
    
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
    """Check the current user's verification status."""
    return {
        "is_verified": current_user.is_verified,
        "role": current_user.role,
        "requires_verification": current_user.role == models.UserRole.PHARMACY
    }
