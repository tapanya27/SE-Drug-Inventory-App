import unittest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import sys
import os

# Add the current directory to sys.path to import models
sys.path.append(os.getcwd())
sys.path.append(os.path.join(os.getcwd(), 'backend'))

import models
import crud
from database import Base

class TestInventoryFilter(unittest.TestCase):
    def setUp(self):
        # Use a fresh in-memory database for testing the logic
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        Session = sessionmaker(bind=self.engine)
        self.db = Session()

        # Create warehouses
        self.w1 = models.User(id=1, name="Warehouse 1", role=models.UserRole.WAREHOUSE)
        self.w5 = models.User(id=5, name="Warehouse 5", role=models.UserRole.WAREHOUSE)
        self.p1 = models.User(id=10, name="Pharmacy 1", role=models.UserRole.PHARMACY)
        self.db.add_all([self.w1, self.w5, self.p1])
        
        # Create medicines
        self.db.add_all([
            models.Medicine(id=1, name="Med W1", owner_id=1, price=10, stock=100, threshold=10),
            models.Medicine(id=2, name="Med W5", owner_id=5, price=20, stock=50, threshold=5),
            models.Medicine(id=3, name="Global Med", owner_id=None, price=5, stock=0, threshold=0)
        ])
        self.db.commit()

    def test_filter_by_warehouse_5(self):
        # Simulate pharmacy fetching inventory for warehouse 5
        # owner_id=5, show_all_warehouses=False (because warehouse_id was provided)
        results = crud.get_medicines(self.db, owner_id=5, show_all_warehouses=False)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].name, "Med W5")
        self.assertEqual(results[0].owner_id, 5)

    def test_filter_all_warehouses(self):
        # Simulate pharmacy fetching all inventory (default behavior)
        results = crud.get_medicines(self.db, owner_id=None, show_all_warehouses=True)
        self.assertEqual(len(results), 2)
        names = [r.name for r in results]
        self.assertIn("Med W1", names)
        self.assertIn("Med W5", names)
        self.assertNotIn("Global Med", names)

    def tearDown(self):
        self.db.close()

if __name__ == "__main__":
    unittest.main()
