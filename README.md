# 🚌 BUSGO — Online Bus Travel Management System

> Sri Lanka public bus management with ML-powered ratings, ETA prediction, and emergency alert prioritization.

## Project Structure

```
busgo/
├── backend/               Node.js + Express REST API
├── frontend/
│   ├── busgo_admin/       React + TypeScript (BUSGO Axis — Admin web app)
│   ├── busgo_client/      Flutter (BUSGO Client — Passenger mobile app)
│   ├── busgo_drive/       Flutter (BUSGO Drive — Driver mobile app)
│   └── busgo_scanner/     Flutter (BUSGO Scanner — QR boarding app)
├── ml_service/            Python Flask — ML model microservice
└── docker-compose.yml     One-command deployment
```

---

## ⚙️ Setup Guide

### Prerequisites
- Node.js 20+
- Python 3.11+
- Flutter 3.22+
- Docker + Docker Compose (optional but recommended)
- A Supabase project (free tier works)

---

### Step 1 — Supabase Database

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** → **New Query**
3. Run `backend/src/db/schema.sql` (creates all 12 tables + RLS)
4. Run `backend/src/db/migration_v2.sql` (adds roles, ML columns, audit log)
5. Run `backend/src/db/seed.sql` (optional sample data)

**Generate admin password hash:**
```bash
node -e "const b=require('bcryptjs'); b.hash('YourSecurePassword', 12).then(console.log)"
```
Update the hash in `migration_v2.sql` before running it.

---

### Step 2 — ML Models

Copy your `.pkl` files to `ml_service/models/`:
```
ml_service/models/
├── bus_rating_model_v5.pkl
├── vectorizer_v5.pkl
├── meta_scaler_v5.pkl
├── meta_feature_names_v5.pkl
├── calibrator_v5.pkl
├── optimized_bus_model.pkl
├── driver_id_encoder.pkl
├── model_metadata.json
├── model_false_alert_xgb.pkl
├── model_priority_lgbm.pkl
├── tfidf_vectorizer.pkl
└── feature_list.pkl
```

---

### Step 3 — Backend Environment

```bash
cd backend
cp .env.example .env
```

Edit `.env` — fill in:
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`, `JWT_RESET_SECRET` (generate with `openssl rand -hex 48`)
- `ML_SERVICE_URL=http://localhost:8000` (or `http://ml_service:8000` in Docker)

---

### Step 4 — Option A: Docker (Recommended)

```bash
# From project root
docker compose up --build
```

This starts:
- **ML Service** on `http://localhost:8000`
- **Node.js API** on `http://localhost:5000`

---

### Step 4 — Option B: Manual

**Start ML service:**
```bash
cd ml_service
pip install -r requirements.txt
python app.py
```

**Start backend:**
```bash
cd backend
npm install
npm run dev
```

---

### Step 5 — Admin Web App (BUSGO Axis)

```bash
cd frontend/busgo_admin
npm install

# Create .env file:
echo "VITE_API_URL=http://localhost:5000/api" > .env

npm run dev
# Opens at http://localhost:5173
```

Login with:
- Email: `admin@busgo.lk`
- Password: whatever you set in Step 1

---

### Step 6 — Flutter Apps

**Update `AppConfig` in each app:**

`busgo_client/lib/core/config/app_config.dart`:
```dart
static const String supabaseUrl     = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

`busgo_client/lib/core/constants/api_constants.dart`:
```dart
// For physical device testing:
const String kBaseUrlDev = 'http://YOUR_PC_IP:5000/api';
// For Android emulator:
const String kBaseUrlDev = 'http://10.0.2.2:5000/api';
```

Apply same IP change to `busgo_drive` and `busgo_scanner`.

**Run each app:**
```bash
# Passenger app
cd frontend/busgo_client && flutter pub get && flutter run

# Driver app
cd frontend/busgo_drive && flutter pub get && flutter run

# Scanner app
cd frontend/busgo_scanner && flutter pub get && flutter run
```

---

## 📡 API Reference

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register passenger/driver |
| POST | `/api/auth/login` | Login (all roles) |
| POST | `/api/auth/refresh` | Refresh access token |
| POST | `/api/auth/logout` | Revoke refresh token |
| POST | `/api/auth/forgot-password/request` | Send reset PIN |
| POST | `/api/auth/forgot-password/verify` | Verify PIN → reset token |
| POST | `/api/auth/forgot-password/reset` | Set new password |

### Buses & Routes (public)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/buses/nearby?lat=&lng=&radius=` | Buses near a location |
| GET | `/api/routes` | All active routes |
| GET | `/api/routes/search?q=` | Search routes |
| GET | `/api/routes/:id/stops` | Stops on a route |
| GET | `/api/stops/nearby?lat=&lng=` | Stops near a location |

### ML-Powered Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/eta/bus/:busId/stop/:stopId` | **Model 2**: ETA prediction |
| POST | `/api/ratings` | **Model 1**: Submit rating → ML scores comment |
| POST | `/api/emergency` | **Model 3**: Send alert → ML prioritizes |

### QR (Scanner App)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/qr/my-card` | Passenger gets their QR token |
| POST | `/api/qr/scan-in` | Driver scans passenger boarding |
| POST | `/api/qr/scan-exit` | Driver scans passenger alighting |

### Driver (BUSGO Drive)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/driver/me` | Driver profile |
| GET | `/api/driver/bus` | Assigned bus + route |
| PATCH | `/api/driver/location` | Update GPS position |
| PATCH | `/api/driver/crowd` | Update crowd level |
| GET | `/api/driver/rating` | My ratings + ML scores |
| GET | `/api/driver/trip/current` | Active passengers on bus |

### Admin (BUSGO Axis)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/admin/dashboard` | Live stats |
| GET | `/api/admin/users` | List all users |
| PATCH | `/api/admin/users/:id/deactivate` | Deactivate user |
| GET | `/api/admin/buses` | All buses |
| POST | `/api/admin/buses` | Add bus |
| GET | `/api/admin/emergency` | All alerts (ML-sorted) |
| PATCH | `/api/admin/emergency/:id/status` | Update alert status |
| GET | `/api/admin/fleet/standby` | Standby buses |
| PATCH | `/api/admin/fleet/:id/deploy` | Deploy standby bus |
| GET | `/api/admin/audit-logs` | Admin action history |

---

## 🤖 ML Models Integration

| Model | Trigger | Input | Output |
|-------|---------|-------|--------|
| Rating Predictor | `POST /api/ratings` with comment | Comment text + context flags | Rating 1–10 + confidence |
| ETA Predictor | `GET /api/eta/bus/:id/stop/:id` | Bus GPS + stops + speed | Minutes to arrival |
| Alert Prioritizer | `POST /api/emergency` | Alert type + comment | Priority 1–5 + false alert detection |

---

## 🏗️ Architecture

```
Flutter Apps ──────────────────────────────────────────────┐
(Client, Drive, Scanner)                                    │
                                                            ▼
React Admin ──────────────────────► Node.js API (Port 5000)
(BUSGO Axis)                              │
                                          ├─► Supabase PostgreSQL (DB)
                                          ├─► Supabase Realtime (live GPS)
                                          └─► Python ML Service (Port 8000)
                                                    │
                                          ┌─────────┴──────────┐
                                    Model 1             Model 2 & 3
                                 (Rating)           (ETA, Alerts)
```

---

## 🔐 User Roles

| Role | App | Access |
|------|-----|--------|
| `passenger` | BUSGO Client | Map, QR, trips, ratings, emergency |
| `driver` | BUSGO Drive + Scanner | Route map, crowd, GPS, emergency |
| `admin` | BUSGO Axis (web) | Full CRUD + fleet + alerts + audit |

Admins are pre-seeded. Passengers and drivers self-register (drivers need admin approval to be assigned a bus).

---

## 🚀 Production Deployment Notes

1. Set `NODE_ENV=production` in backend `.env`
2. Set `AppEnvironment.production` in each Flutter `app_config.dart`
3. Generate fresh JWT secrets (never reuse dev secrets)
4. Configure CORS: add your production domain to `CORS_ORIGINS`
5. Enable Firebase Cloud Messaging in Flutter apps for push notifications
6. Replace `admin@busgo.lk` default password immediately after first login
7. Consider Azure (as planned in project docs) for production hosting
