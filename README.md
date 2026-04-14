# 💊 PharmaSupply System

[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Stripe](https://img.shields.io/badge/Payments-Stripe-6772E5?style=flat-square&logo=stripe&logoColor=white)](https://stripe.com/)
[![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org/)

A professional, role-based pharmaceutical supply chain management platform. PharmaSupply connects **Pharmacy Stores**, **Warehouses**, and **Manufacturers (Companies)** into a unified ecosystem with secure payments, AI-driven verification, and real-time inventory tracking.

---

## ✨ Key Pillars

*   **🔒 Secure Identity**: `V3 Canary Security Engine` for AI-powered document verification and zero-trust role management.
*   **📦 Smart Inventory**: Real-time stock tracking with low-stock alerts and demand prediction models.
*   **💳 Seamless Payments**: Integrated Stripe checkout for secure B2B pharmaceutical transactions.
*   **📊 Cross-Platform**: Premium Flutter experience for mobile and web, backed by a high-performance FastAPI server.

---

## 🛠 Tech Stack

### Backend
- **Framework**: [FastAPI](https://fastapi.tiangolo.com/) (Python)
- **Database**: [PostgreSQL](https://www.postgresql.org/) (via `psycopg` and `SQLAlchemy`).
- **Security**: JWT (Jose) Auth, Bcrypt hashing, and Domain-Restricted signups.
- **Payments**: Stripe API integration.

### AI Verification Stack (V3 Canary Engine)
- **OCR Engine**: [Tesseract OCR](https://github.com/tesseract-ocr/tesseract) for high-accuracy text extraction from licenses.
- **Image Processing**: [Pillow (PIL)](https://python-pillow.org/) for document analysis and heuristic authenticity checks.
- **Intelligence**: Custom heuristic engine with:
    - Regex-driven field extraction (License numbers, Issue/Expiry dates).
    - Confidence scoring (0-100) based on clarity, completeness, and validity.
    - Zero-Trust binary safety guards and fraud pattern recognition.

### Frontend
- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **State Management**: Provider
- **Navigation**: GoRouter
- **Styling**: Google Fonts (Inter/Roboto), Material 3 Design.

---

## 🎭 Role-Based Features

### 🏥 Pharmacy Store
- **Identity**: Must use `@pharmacysupply.com` email.
- **Verification**: Upload licenses for AI-powered approval.
- **Marketplace**: Browse warehouse catalogs and place bulk orders.
- **Checkout**: Secure payment intent generation via Stripe.

### 🏭 Warehouse
- **Stock Control**: Manage local inventory and set replenishment thresholds.
- **Fulfillment**: Track and update order statuses (*Processing* → *Dispatched* → *Delivered*).
- **Analytics**: View demand spikes and warehouse-specific stats.

### 🏢 Company (Manufacturer)
- **Catalog Management**: Maintain the global medicine list.
- **Supply Chain**: Replenish warehouse stocks based on demand requests.
- **Audit**: High-level overview of low-stock items across the network.

---

## 📂 Project Structure

```text
SE-Drug-App/
├── backend/                # FastAPI Application
│   ├── main.py             # Server entry point & API routes
│   ├── models.py           # Database schemas (SQLAlchemy)
│   ├── crud.py             # Database operations
│   ├── schemas.py          # Pydantic models
│   ├── verification_service.py # AI Verification Engine (OCR + Heuristics)
│   └── .env                # Postgres & API configuration
├── pharma_supply/          # Flutter Application
│   ├── lib/
│   │   ├── core/           # Routing & Design System
│   │   ├── features/       # Role-specific UI & Logic
│   │   └── main.dart       # App entry point
│   └── pubspec.yaml        # Flutter dependencies
└── scratch/                # Developer tools & Debug scripts
```

---

## 🚀 Getting Started

### 1. Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # 或 venv\Scripts\activate on Windows
pip install -r requirements.txt
```
**Environment Configuration**: Create a `.env` file in `/backend`:
```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
SECRET_KEY=your_jwt_secret
```
**Run Server**:
```bash
uvicorn main:app --reload --port 8005
```

### 2. Frontend Setup
```bash
cd pharma_supply
flutter pub get
flutter run
```

---

## 🛡 Security & Compliance

The system implements a **Zero-Trust** architecture for Pharmacy accounts:
1. **Domain Restriction**: Only `@pharmacysupply.com` emails are accepted for Pharmacies.
2. **AI Verification**: Uploaded documents are analyzed for confidence scores.
3. **Self-Healing Audit**: The system automatically resets verification status if a user lacks the required approved documentation.

---
*Developed with 💙 for the Pharmaceutical Supply Chain.*