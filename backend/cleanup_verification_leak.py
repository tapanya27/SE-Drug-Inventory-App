import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

import models

load_dotenv('backend/.env')
db_url = os.getenv("DATABASE_URL").replace("postgresql://", "postgresql+psycopg://")
engine = create_engine(db_url)
SessionLocal = sessionmaker(bind=engine)

def cleanup_verification_leak():
    db = SessionLocal()
    try:
        # 1. Find all verified pharmacies
        pharmacies = db.query(models.User).filter(
            models.User.role == models.UserRole.PHARMACY,
            models.User.is_verified == True
        ).all()
        
        print(f"Auditing {len(pharmacies)} verified pharmacies...")
        
        revoked_count = 0
        for p in pharmacies:
            # Check for ANY approved document
            approved_doc = db.query(models.Document).filter(
                models.Document.user_id == p.id,
                models.Document.status == models.DocStatus.APPROVED
            ).first()
            
            if not approved_doc:
                print(f"REVOKING: User {p.id} ({p.name}) has no approved documents.")
                p.is_verified = False
                revoked_count += 1
        
        db.commit()
        print(f"\nCleanup complete. Revoked verification for {revoked_count} accounts.")
        
    finally:
        db.close()

if __name__ == "__main__":
    cleanup_verification_leak()
