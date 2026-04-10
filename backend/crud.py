from sqlalchemy.orm import Session
from sqlalchemy import func
import models, schemas, auth_utils
from datetime import datetime, date

def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()

def create_user(db: Session, user: schemas.UserCreate):
    hashed_password = auth_utils.get_password_hash(user.password)
    db_user = models.User(
        name=user.name,
        email=user.email,
        password_hash=hashed_password,
        role=user.role
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_medicines(db: Session, owner_id: int = None, show_all_warehouses: bool = False, skip: int = 0, limit: int = 100):
    query = db.query(models.Medicine)
    if owner_id:
        # Strictly show only owner-specific items (no global items)
        query = query.filter(models.Medicine.owner_id == owner_id)
    elif show_all_warehouses:
        # Show all items owned by ANY warehouse (for Pharmacies to order from)
        query = query.filter(models.Medicine.owner_id != None)
    else:
        # If no owner_id and not showing all, show purely global catalog (used by Admin/Company)
        query = query.filter(models.Medicine.owner_id == None)
    
    results = query.offset(skip).limit(limit).all()
    return [schemas.MedicineResponse.from_orm(med) for med in results]

def get_catalog(db: Session):
    # Returns all medicine templates (ones with no owner)
    return db.query(models.Medicine).filter(models.Medicine.owner_id == None).all()

def add_to_inventory(db: Session, medicine_id: int, user_id: int):
    # Clone a catalog item for a specific warehouse
    catalog_item = db.query(models.Medicine).filter(models.Medicine.id == medicine_id, models.Medicine.owner_id == None).first()
    if not catalog_item:
        return None
    
    # Check if they already have it
    existing = db.query(models.Medicine).filter(models.Medicine.name == catalog_item.name, models.Medicine.owner_id == user_id).first()
    if existing:
        return existing
        
    db_med = models.Medicine(
        name=catalog_item.name,
        price=catalog_item.price,
        stock=0, # Start with empty stock
        threshold=catalog_item.threshold,
        owner_id=user_id
    )
    db.add(db_med)
    db.commit()
    db.refresh(db_med)
    return db_med

def create_order(db: Session, order: schemas.OrderCreate, user_id: int):
    # Calculate total and generate summary
    total = 0.0
    summary_parts = []
    
    db_order = models.Order(user_id=user_id, total_amount=0, items_summary="")
    db.add(db_order)
    db.commit()
    db.refresh(db_order)

    for item in order.items:
        medicine = db.query(models.Medicine).filter(models.Medicine.id == item.medicine_id).first()
        if medicine:
            total += medicine.price * item.quantity
            summary_parts.append(f"{medicine.name} ({item.quantity})")
            
            db_item = models.OrderItem(
                order_id=db_order.id,
                medicine_id=item.medicine_id,
                quantity=item.quantity
            )
            db.add(db_item)

    db_order.total_amount = total
    db_order.items_summary = ", ".join(summary_parts)
    db.commit()
    db.refresh(db_order)
    return db_order

def get_user_orders(db: Session, user_id: int):
    return db.query(models.Order).filter(models.Order.user_id == user_id).all()

def get_all_orders(db: Session):
    orders = db.query(models.Order).all()
    output = []
    for o in orders:
        ord_res = schemas.OrderResponse.from_orm(o)
        ord_res.user_name = o.user.name if o.user else "Unknown"
        ord_res.user_role = o.user.role if o.user else "Unknown"
        output.append(ord_res)
    return output

def update_order_status(db: Session, order_id: int, status: models.OrderStatus, fulfiller_id: int = None):
    db_order = db.query(models.Order).filter(models.Order.id == order_id).first()
    warnings = []
    
    if db_order:
        # If we are dispatching this order, deduct stock now
        if db_order.status != status and status == models.OrderStatus.DISPATCHED:
            print(f"DEBUG: Processing dispatch for Order #{order_id} by Fulfiller {fulfiller_id}. Deducting stock...")
            for item in db_order.items:
                medicine = item.medicine
                if medicine:
                    target_medicine = medicine
                    
                    # SELF-HEALING LOGIC:
                    # If the medicine in the order is a Global Catalog item (Owner is None),
                    # attempt to find the fulfiller's private copy of this medicine by name.
                    if medicine.owner_id is None and fulfiller_id is not None:
                        warehouse_copy = db.query(models.Medicine).filter(
                            models.Medicine.name == medicine.name,
                            models.Medicine.owner_id == fulfiller_id
                        ).first()
                        if warehouse_copy:
                            print(f"DEBUG: Redirecting deduction from Template (ID: {medicine.id}) to Warehouse Copy (ID: {warehouse_copy.id})")
                            target_medicine = warehouse_copy
                    
                    print(f"DEBUG: Medicine {target_medicine.name} (ID: {target_medicine.id}, Owner: {target_medicine.owner_id}) Stock: {target_medicine.stock} -> {target_medicine.stock - item.quantity}")
                    target_medicine.stock -= item.quantity
                    
                    if target_medicine.stock <= 100:
                        warnings.append(f"{target_medicine.name} stock critically low ({target_medicine.stock} left).")
                else:
                    print(f"WARNING: Item in Order #{order_id} has no medicine reference (ID: {item.medicine_id})")
        
        db_order.status = status
        db.commit()
        db.refresh(db_order)
        
    return db_order, warnings

def get_warehouse_stats(db: Session, owner_id: int):
    # Count pending orders that contain medicines owned by this warehouse
    pending_dispatch = db.query(models.Order).filter(
        models.Order.status == models.OrderStatus.PROCESSING,
        models.Order.items.any(models.OrderItem.medicine.has(models.Medicine.owner_id == owner_id))
    ).count()

    # Count medicines owned by this warehouse that are at or below threshold
    low_stock = db.query(models.Medicine).filter(
        models.Medicine.owner_id == owner_id,
        models.Medicine.stock <= models.Medicine.threshold
    ).count()
    
    # Count delivered orders containing medicines owned by this warehouse
    today_start = datetime.combine(date.today(), datetime.min.time())
    delivered_today = db.query(models.Order).filter(
        models.Order.status == models.OrderStatus.DELIVERED,
        models.Order.order_date >= today_start,
        models.Order.items.any(models.OrderItem.medicine.has(models.Medicine.owner_id == owner_id))
    ).count()
    
    return {
        "pending_dispatch": pending_dispatch,
        "low_stock": low_stock,
        "delivered_today": delivered_today
    }

def request_stock(db: Session, medicine_id: int):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine:
        db_medicine.is_requested = True
        db.commit()
        db.refresh(db_medicine)
    return db_medicine

def replenish_stock(db: Session, medicine_id: int):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine:
        db_medicine.is_requested = False
        db_medicine.stock += 500 # Fixed replenishment amount
        db.commit()
        db.refresh(db_medicine)
    return db_medicine

def get_demand_prediction(db: Session):
    # Heuristic: Ordered more than 3 times in the last 7 days
    from datetime import timedelta
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    
    # Query order items and group by medicine
    results = db.query(
        models.OrderItem.medicine_id,
        func.count(models.OrderItem.id).label("order_count")
    ).join(models.Order).filter(
        models.Order.order_date >= seven_days_ago
    ).group_by(models.OrderItem.medicine_id).all()
    
    high_demand_ids = [r.medicine_id for r in results if r.order_count >= 3]
    
    return db.query(models.Medicine).filter(models.Medicine.id.in_(high_demand_ids)).all() if high_demand_ids else []
