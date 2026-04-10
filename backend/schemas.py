from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional
from datetime import datetime
from models import UserRole, OrderStatus, DocStatus

class UserBase(BaseModel):
    name: str
    email: EmailStr
    role: UserRole

class UserCreate(UserBase):
    password: str = Field(..., min_length=8, regex=r"^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$")

class UserResponse(UserBase):
    id: int
    is_verified: bool = False
    class Config:
        orm_mode = True

class MedicineBase(BaseModel):
    name: str
    price: float
    stock: int
    threshold: int
    is_requested: bool = False

class MedicineResponse(MedicineBase):
    id: int
    owner_name: Optional[str] = None
    class Config:
        orm_mode = True

class OrderItemBase(BaseModel):
    medicine_id: int
    quantity: int

class OrderCreate(BaseModel):
    items: List[OrderItemBase]

class OrderResponse(BaseModel):
    id: int
    order_date: datetime
    status: OrderStatus
    total_amount: float
    items_summary: str
    user_name: Optional[str] = None
    user_role: Optional[str] = None
    class Config:
        orm_mode = True

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    email: str
    password: str

class DocumentResponse(BaseModel):
    id: int
    filename: str
    doc_type: str
    status: DocStatus
    rejection_reason: Optional[str] = None
    uploaded_at: datetime
    reviewed_at: Optional[datetime] = None
    class Config:
        orm_mode = True

