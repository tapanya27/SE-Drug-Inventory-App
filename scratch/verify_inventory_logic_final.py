import unittest
from sqlalchemy import create_engine, Column, Integer, String, Boolean, Enum, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
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

# Re-implementing the core logic for the test
def get_medicines_logic(db, owner_id=None, show_all_warehouses=False):
    query = db.query(Medicine)
    if owner_id:
        query = query.filter(Medicine.owner_id == owner_id)
    elif show_all_warehouses:
        query = query.filter(Medicine.owner_id != None)
    else:
        query = query.filter(Medicine.owner_id == None)
    return query.all()

class TestInventoryLogicFinal(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        Session = sessionmaker(bind=self.engine)
        self.db = Session()

        # Seed data
        self.db.add_all([
            User(id=1, name="Warehouse 1", role=UserRole.WAREHOUSE),
            User(id=5, name="Warehouse 5", role=UserRole.WAREHOUSE),
            Medicine(id=1, name="Item 1", owner_id=1),
            Medicine(id=2, name="Item 5", owner_id=5),
            Medicine(id=10, name="Global Item", owner_id=None)
        ])
        self.db.commit()

    def test_warehouse_5_filter(self):
        # Pharmacy selects Warehouse 5
        # Backend receives warehouse_id=5
        # logic: owner_id = 5, show_all = False
        results = get_medicines_logic(self.db, owner_id=5, show_all_warehouses=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].name, "Item 5")

    def test_default_all_warehouses(self):
        # Pharmacy default view (all warehouses)
        # Backend receives warehouse_id=None
        # logic: owner_id = None, show_all = True
        results = get_medicines_logic(self.db, owner_id=None, show_all_warehouses=True)
        self.assertEqual(len(results), 2)
        names = [r.name for r in results]
        self.assertIn("Item 1", names)
        self.assertIn("Item 5", names)

if __name__ == "__main__":
    unittest.main()
