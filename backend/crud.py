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
        role=user.role,
        license_number=user.license_number
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def get_medicines(db: Session, owner_id: int = None, skip: int = 0, limit: int = 100):
    """
    Fetch medicines strictly owned by a specific user.
    Used for personal 'Store Inventory' or 'Warehouse Dashboard'.
    """
    print(f"DATABASE QUERY: get_medicines (Personal) for owner_id: {owner_id}")
    
    query = db.query(models.Medicine).filter(models.Medicine.owner_id == owner_id)
    results = query.offset(skip).limit(limit).all()
    
    print(f"Total personal results found: {len(results)}")
    return [schemas.MedicineResponse.from_orm(med) for med in results]

def get_marketplace_medicines(db: Session, skip: int = 0, limit: int = 100):
    """
    Fetch all medicines owned by ANY warehouse.
    Used by Pharmacies to browse and order from.
    """
    print("DATABASE QUERY: get_marketplace_medicines")
    query = db.query(models.Medicine).filter(models.Medicine.owner_id != None)
    
    results = query.offset(skip).limit(limit).all()
    
    print(f"Total marketplace results found: {len(results)}")
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
    
    db_order = models.Order(
        user_id=user_id, 
        fulfiller_id=order.warehouse_id,
        total_amount=0, 
        items_summary=""
    )
    db.add(db_order)
    db.commit()
    db.refresh(db_order)

    for item in order.items:
        medicine = db.query(models.Medicine).filter(models.Medicine.id == item.medicine_id).first()
        if medicine:
            # Check availability in Fulfiller's stock
            fulfiller_med = db.query(models.Medicine).filter(
                models.Medicine.name == medicine.name,
                models.Medicine.owner_id == order.warehouse_id
            ).first()
            available_stock = fulfiller_med.stock if fulfiller_med else 0
            if item.quantity > available_stock:
                db.rollback()
                from fastapi import HTTPException
                raise HTTPException(status_code=400, detail=f"Order quantity exceeds available stock for {medicine.name}.")

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

def get_all_orders(db: Session, fulfiller_id: int = None):
    query = db.query(models.Order)
    if fulfiller_id:
        query = query.filter(models.Order.fulfiller_id == fulfiller_id)
    
    orders = query.all()
    output = []
    for o in orders:
        ord_res = schemas.OrderResponse.from_orm(o)
        ord_res.user_name = o.user.name if o.user else "Unknown"
        ord_res.user_role = o.user.role if o.user else "Unknown"
        ord_res.warehouse_id = o.fulfiller_id
        ord_res.warehouse_name = o.fulfiller.name if o.fulfiller else "Unknown"
        output.append(ord_res)
    return output


def update_order_status(db: Session, order_id: int, status: models.OrderStatus, fulfiller_id: int = None):
    db_order = db.query(models.Order).filter(models.Order.id == order_id).first()
    warnings = []
    
    if db_order:
        old_status = db_order.status
        
        # 1. DISPATCH Logic (Deduct from Warehouse)
        if old_status != status and status == models.OrderStatus.DISPATCHED:
            print(f"DEBUG: Processing dispatch for Order #{order_id} by Fulfiller {fulfiller_id}. Deducting stock...")
            for item in db_order.items:
                medicine = item.medicine
                if medicine:
                    target_medicine = medicine
                    
                    # SELF-HEALING LOGIC:
                    target_fulfiller_id = db_order.fulfiller_id or fulfiller_id
                    
                    if medicine.owner_id is None and target_fulfiller_id is not None:
                        warehouse_copy = db.query(models.Medicine).filter(
                            models.Medicine.name == medicine.name,
                            models.Medicine.owner_id == target_fulfiller_id
                        ).first()
                        if warehouse_copy:
                            print(f"DEBUG: Redirecting deduction to Warehouse Copy (ID: {warehouse_copy.id})")
                            target_medicine = warehouse_copy

                    print(f"DEBUG: Medicine {target_medicine.name} ID: {target_medicine.id} Stock: {target_medicine.stock} -> {target_medicine.stock - item.quantity}")
                    target_medicine.stock -= item.quantity
                    
                    if target_medicine.stock <= target_medicine.threshold:
                        warnings.append(f"{target_medicine.name} stock critically low ({target_medicine.stock} left).")
                else:
                    print(f"WARNING: Item in Order #{order_id} has no medicine reference")

        # 2. DELIVERY Logic (Add to Pharmacy)
        if old_status != status and status == models.OrderStatus.DELIVERED:
            db_order.delivery_date = datetime.now()
            print(f"DEBUG: Processing DELIVERY for Order #{order_id}. Adding to Pharmacy {db_order.user_id}...")
            for item in db_order.items:
                # Find or create this medicine record for the Pharmacy
                pharmacy_med = db.query(models.Medicine).filter(
                    models.Medicine.name == item.medicine.name,
                    models.Medicine.owner_id == db_order.user_id
                ).first()
                
                if pharmacy_med:
                    print(f"DEBUG: Updating existing stock for {item.medicine.name} (+{item.quantity})")
                    pharmacy_med.stock += item.quantity
                else:
                    print(f"DEBUG: Creating new stock record for {item.medicine.name} (Pharmacy {db_order.user_id})")
                    new_med = models.Medicine(
                        name=item.medicine.name,
                        price=item.medicine.price,
                        stock=item.quantity,
                        threshold=item.medicine.threshold,
                        owner_id=db_order.user_id
                    )
                    db.add(new_med)
        
        db_order.status = status
        db.commit()
        db.refresh(db_order)
        
    return db_order, warnings

def get_warehouse_stats(db: Session, owner_id: int):
    # Count pending orders explicitly assigned to this warehouse
    pending_dispatch = db.query(models.Order).filter(
        models.Order.status == models.OrderStatus.PROCESSING,
        models.Order.fulfiller_id == owner_id
    ).count()

    # Count medicines owned by this warehouse that are strictly below threshold
    low_stock = db.query(models.Medicine).filter(
        models.Medicine.owner_id == owner_id,
        models.Medicine.stock < models.Medicine.threshold
    ).count()
    
    # Count delivered orders explicitly assigned to this warehouse
    today_start = datetime.combine(date.today(), datetime.min.time())
    delivered_orders = db.query(models.Order).filter(
        models.Order.status == models.OrderStatus.DELIVERED,
        models.Order.fulfiller_id == owner_id
    ).order_by(models.Order.order_date.desc()).all()
    
    delivered_today_count = sum(1 for o in delivered_orders if o.order_date >= today_start)
    
    items_received_today = 0
    for o in delivered_orders:
        if o.order_date >= today_start:
            for item in o.items:
                items_received_today += item.quantity
    
    return {
        "pending_dispatch": pending_dispatch,
        "low_stock": low_stock,
        "delivered_today": delivered_today_count,
        "items_received_today": items_received_today,
        "total_delivered": len(delivered_orders)
    }


def request_stock(db: Session, medicine_id: int, quantity: int = 500):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine:
        db_medicine.is_requested = True
        db_medicine.requested_quantity = quantity
        db.commit()
        db.refresh(db_medicine)
    return db_medicine

def replenish_stock(db: Session, medicine_id: int):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine:
        db_medicine.is_requested = False
        replenish_amt = db_medicine.requested_quantity if db_medicine.requested_quantity and db_medicine.requested_quantity > 0 else 500
        db_medicine.stock += replenish_amt
        db_medicine.requested_quantity = 0
        db.commit()
        db.refresh(db_medicine)
    return db_medicine

def consume_stock(db: Session, medicine_id: int, quantity: int):
    db_medicine = db.query(models.Medicine).filter(models.Medicine.id == medicine_id).first()
    if db_medicine:
        if db_medicine.stock < quantity:
            from fastapi import HTTPException
            raise HTTPException(status_code=400, detail="Not enough stock")
        db_medicine.stock -= quantity
        db.commit()
        db.refresh(db_medicine)
    return db_medicine

def get_demand_prediction(db: Session):
    # Heuristic: Ordered more than 3 times in the last 7 days
    from datetime import timedelta
    seven_days_ago = datetime.now() - timedelta(days=7)
    
    # Query order items and group by medicine
    results = db.query(
        models.OrderItem.medicine_id,
        func.count(models.OrderItem.id).label("order_count")
    ).join(models.Order).filter(
        models.Order.order_date >= seven_days_ago
    ).group_by(models.OrderItem.medicine_id).all()
    
    high_demand_ids = [r.medicine_id for r in results if r.order_count >= 3]
    
def delete_user(db: Session, user_id: int):
    # Cascading delete manually for safety
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        return False
        
    # Delete documents
    db.query(models.Document).filter(models.Document.user_id == user_id).delete()
    
    # Delete medicines they own
    db.query(models.Medicine).filter(models.Medicine.owner_id == user_id).delete()
    
    # Delete orders they placed and items within those orders
    orders_placed = db.query(models.Order).filter(models.Order.user_id == user_id).all()
    for o in orders_placed:
        db.query(models.OrderItem).filter(models.OrderItem.order_id == o.id).delete()
    db.query(models.Order).filter(models.Order.user_id == user_id).delete()
    
    # Delete orders they fulfill
    orders_fulfilled = db.query(models.Order).filter(models.Order.fulfiller_id == user_id).all()
    for o in orders_fulfilled:
        db.query(models.OrderItem).filter(models.OrderItem.order_id == o.id).delete()
    db.query(models.Order).filter(models.Order.fulfiller_id == user_id).delete()
    
    db.delete(user)
    db.commit()
    return True
