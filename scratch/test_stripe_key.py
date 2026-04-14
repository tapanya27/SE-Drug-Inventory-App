import os
import stripe
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), "..", "backend", ".env")
load_dotenv(dotenv_path)

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

try:
    print(f"Attempting to CREATE PaymentIntent...")
    intent = stripe.PaymentIntent.create(
        amount=4375, # $43.75 in cents
        currency="usd",
        automatic_payment_methods={"enabled": True},
        metadata={"user_id": 1} # Mock user ID
    )
    print(f"SUCCESS: PaymentIntent created! ID: {intent.id}")
except Exception as e:
    print(f"FAILURE: Stripe error: {str(e)}")
