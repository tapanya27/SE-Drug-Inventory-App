from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Enum, Boolean
from sqlalchemy.orm import relationship
from database import Base
import enum
from datetime import datetime

class UserRole(str, enum.Enum):
    PHARMACY = "Pharmacy Store"
    WAREHOUSE = "Warehouse"
    COMPANY = "Company"
    ADMIN = "Admin"

class OrderStatus(str, enum.Enum):
    PROCESSING = "Processing"
    DISPATCHED = "Dispatched"
    DELIVERED = "Delivered"

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    role = Column(Enum(UserRole))
    is_verified = Column(Boolean, default=False)
    license_number = Column(String, nullable=True)

    medicines = relationship("Medicine", back_populates="owner")
    documents = relationship("Document", back_populates="owner")

class Medicine(Base):
    __tablename__ = "medicines"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    price = Column(Float)
    stock = Column(Integer)
    threshold = Column(Integer)
    is_requested = Column(Boolean, default=False)
    requested_quantity = Column(Integer, default=0)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True) # NULL means global catalog

    owner = relationship("User", back_populates="medicines")

    @property
    def owner_name(self):
        return self.owner.name if self.owner else "Global Catalog"

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    fulfiller_id = Column(Integer, ForeignKey("users.id"), nullable=True) # The warehouse fulfilling this order
    order_date = Column(DateTime, default=datetime.now)
    delivery_date = Column(DateTime, nullable=True)
    status = Column(Enum(OrderStatus), default=OrderStatus.PROCESSING)
    total_amount = Column(Float)
    items_summary = Column(String) # For simplified UI display

    user = relationship("User", foreign_keys=[user_id])
    fulfiller = relationship("User", foreign_keys=[fulfiller_id])
    items = relationship("OrderItem", back_populates="order")


class OrderItem(Base):
    __tablename__ = "order_items"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    medicine_id = Column(Integer, ForeignKey("medicines.id"))
    quantity = Column(Integer)

    order = relationship("Order", back_populates="items")
    medicine = relationship("Medicine")

class DocStatus(str, enum.Enum):
    PENDING = "Pending"
    APPROVED = "Approved"
    REJECTED = "Rejected"

class Document(Base):
    __tablename__ = "documents"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    filename = Column(String)
    file_path = Column(String)
    doc_type = Column(String)  # e.g. "pharmacy_license", "registration_cert"
    status = Column(Enum(DocStatus), default=DocStatus.PENDING)
    rejection_reason = Column(String, nullable=True)
    ai_score = Column(Integer, nullable=True)
    extracted_data = Column(String, nullable=True) # JSON string
    verification_issues = Column(String, nullable=True) # JSON string
    uploaded_at = Column(DateTime, default=datetime.now)
    reviewed_at = Column(DateTime, nullable=True)

    owner = relationship("User", back_populates="documents")

