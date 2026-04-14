import unittest
from sqlalchemy import create_engine, Column, Integer, String, Boolean, Enum, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
import enum

Base = declarative_base()

class UserRole(str, enum.Enum):
    PHARMACY = "Pharmacy Store"
    WAREHOUSE = "Warehouse"

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String)
    role = Column(Enum(UserRole))

class Medicine(Base):
    __tablename__ = "medicines"
    id = Column(Integer, primary_key=True)
    name = Column(String)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)

def get_medicines(db, owner_id=None, show_all_warehouses=False):
    query = db.query(Medicine)
    if owner_id:
        query = query.filter(Medicine.owner_id == owner_id)
    elif show_all_warehouses:
        query = query.filter(Medicine.owner_id != None)
    else:
        query = query.filter(Medicine.owner_id == None)
    return query.all()

class TestInventory(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        Session = sessionmaker(bind=self.engine)
        self.db = Session()

        # Seed data
        self.w1 = User(id=1, name="Warehouse1", role=UserRole.WAREHOUSE)
        self.w5 = User(id=5, name="Warehouse5", role=UserRole.WAREHOUSE)
        self.p1 = User(id=10, name="Pharmacy1", role=UserRole.PHARMACY)
        self.db.add_all([self.w1, self.w5, self.p1])
        
        self.m1 = Medicine(id=1, name="Med1", owner_id=1)
        self.m5 = Medicine(id=5, name="Med5", owner_id=5)
        self.mg = Medicine(id=100, name="MedGlobal", owner_id=None)
        self.db.add_all([self.m1, self.m5, self.mg])
        self.db.commit()

    def test_pharmacy_view(self):
        # Pharmacy view (show_all_warehouses=True)
        results = get_medicines(self.db, show_all_warehouses=True)
        names = [r.name for r in results]
        self.assertIn("Med1", names)
        self.assertIn("Med5", names)
        self.assertNotIn("MedGlobal", names)
        print("Pharmacy View Results:", names)

    def test_warehouse_view(self):
        # Warehouse 5 view
        results = get_medicines(self.db, owner_id=5)
        names = [r.name for r in results]
        self.assertEqual(names, ["Med5"])
        print("Warehouse 5 View Results:", names)

if __name__ == "__main__":
    unittest.main()
