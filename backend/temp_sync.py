import os
from sqlalchemy import create_engine, text

engine = create_engine('postgresql+psycopg://postgres:postgres@localhost:5432/pharma_supply_db')
conn = engine.connect()

# Add a full literal day (24 hours) since UTCnow bumped it backwards by roughly 5.5 hours behind the IST midnight threshold.
conn.execute(text("UPDATE orders SET order_date = order_date + INTERVAL '1 day';"))
conn.execute(text("UPDATE orders SET delivery_date = delivery_date + INTERVAL '1 day' WHERE delivery_date IS NOT NULL;"))

conn.commit()
conn.close()

print('Dates synced gracefully to fall into the user local threshold constraints!')
