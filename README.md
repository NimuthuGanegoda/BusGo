# BUSGO - Sri Lanka Bus Management System

A real-time bus tracking and management platform for Sri Lanka, featuring live GPS tracking, ETA predictions powered by machine learning, QR-based boarding, and a crowd monitoring system.

## Overview

BUSGO consists of 4 frontend apps and 2 backend services that work together to provide real-time bus tracking for passengers, drivers, and administrators.

### System Architecture

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│  Client App  │     │  Drive App  │     │ Scanner App  │
│  (Flutter)   │     │  (Flutter)  │     │  (Flutter)   │
│  Passenger   │     │   Driver    │     │  QR Boarding │
└──────┬───────┘     └──────┬──────┘     └──────┬───────┘
       │                    │                    │
       │         ┌──────────┴──────────┐         │
       └────────►│   Backend API       │◄────────┘
                 │   Node.js/Express   │
                 │   Port 5000         │
                 └──────────┬──────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼                           ▼
    ┌──────────────┐            ┌──────────────┐
    │  Supabase    │            │  ML Service  │
    │  PostgreSQL  │            │  Flask/Python │
    │  + Realtime  │            │  Port 8000   │
    └──────────────┘            └──────────────┘
                                       │
                 ┌─────────────────────┬┘
                 ▼                     ▼
          ┌────────────┐      ┌──────────────┐
          │  ETA Model │      │ Rating Model │
          │  (sklearn) │      │  (sklearn)   │
          └────────────┘      └──────────────┘

    ┌─────────────┐
    │ Admin Panel  │
    │ React + TS   │
    │ Port 5173    │
    └──────┬───────┘
           │
           └────────►  Backend API
```

## Project Structure

```
busgo/
├── backend/                        Node.js/Express API (Port 5000)
│   └── src/modules/
│       ├── auth/                   JWT authentication
│       ├── buses/                  Bus data & nearby search
│       ├── driver/                 Driver location, status, crowd
│       ├── eta/                    ETA calculation endpoint
│       ├── admin/                  Admin panel endpoints
│       ├── scanner/                QR boarding system
│       ├── ratings/                Passenger ratings
│       └── alerts/                 Alert system
│
├── ml_service/                     Python/Flask ML API (Port 8000)
│   ├── app.py                      Flask application entry point
│   └── models/
│       ├── eta_predictor           ETA prediction (sklearn)
│       ├── rating_predictor        Rating analysis (sklearn)
│       └── alert_prioritizer       Two-stage alert prioritization (XGBoost + LightGBM + SBERT)
│
├── frontend/
│   ├── busgo_client/               Flutter - Passenger App
│   │   └── lib/
│   │       ├── screens/
│   │       │   ├── map/            Live map with bus tracking
│   │       │   └── search/         Route & destination search
│   │       ├── providers/          State management (Provider)
│   │       ├── services/           API & location services
│   │       └── models/             Data models
│   │
│   ├── busgo_drive/                Flutter - Driver App
│   │   └── lib/
│   │       ├── screens/dashboard/  Toggle online/offline, GPS
│   │       ├── providers/          Auth, trip, route providers
│   │       └── services/           Location & API services
│   │
│   ├── busgo_scanner/              Flutter - QR Scanner App
│   │
│   └── busgo_admin/                React + TypeScript Admin Panel
│       └── src/pages/
│           ├── FleetMap.tsx         Real-time fleet map
│           ├── Dashboard.tsx        Admin dashboard
│           └── ...
```

## Features

### Passenger App (busgo_client)
- **Live Map** — Real-time bus tracking on an interactive map with MapTiler tiles
- **ETA Predictions** — ML-powered arrival time estimates to nearest bus stop
- **Route Search** — Search by destination with per-bus ETA display
- **Crowd Levels** — See how full each bus is before boarding (low / moderate / high / full)
- **Bus Details** — Tap any bus for route info, driver name, speed, and crowd level

### Driver App (busgo_drive)
- **Online/Offline Toggle** — Go online to start broadcasting GPS location
- **Live GPS Tracking** — Continuous location updates every 10 seconds
- **Passenger Count** — Real-time boarding count via Supabase Realtime
- **Dashboard** — Map preview, trip info, and quick controls
- **Profile & Logout** — Proper session management with bus status reset

### Admin Panel (busgo_admin)
- **Fleet Map** — Live view of all active buses with GPS freshness indicators
- **Bus Management** — Monitor bus status, speed, crowd levels, and driver info
- **Route Management** — View and manage all 28 routes and 372 bus stops
- **Real-time Updates** — Auto-refreshes every 10 seconds with live/stale indicators

### Scanner App (busgo_scanner)
- **QR Boarding** — Scan passenger QR codes for trip boarding/alighting
- **Trip Management** — Track active trips per bus

### ML Service
- **ETA Predictor** — Estimates bus arrival time using distance, speed, traffic context, and historical patterns
- **Rating Predictor** — Analyzes passenger ratings with ML confidence scoring
- **Alert Prioritizer** — Two-stage emergency alert prioritization pipeline trained on 663,522+ real Montgomery County 911 records mapped to Sri Lanka bus emergency categories, plus Sri Lanka-specific synthetic data:
  - **Stage 1 — False Alert Detector (XGBoost + TF-IDF):** Classifies incoming alerts as real or false/accidental using 14 engineered structural features (urgency score, keyword counts, gibberish detection, comment length, etc.) combined with 800-dimensional TF-IDF text vectors
  - **Stage 2 — Priority Scorer (LightGBM + SBERT):** For real alerts, assigns a priority score (2–5: LOW → CRITICAL) using the same structural features combined with 384-dimensional SBERT semantic embeddings (sentence-transformers/all-MiniLM-L6-v2) that capture the contextual meaning of passenger comments
  - **Priority Scale:** 5 = CRITICAL (dispatch immediately), 4 = HIGH (urgent response), 3 = MEDIUM (monitor), 2 = LOW (log and follow-up), 1 = FALSE (flag for review)
  - **Emergency Categories:** Medical Emergency, Criminal Activity, Bus Breakdown, Harassment, Other

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend API | Node.js, Express, Zod validation |
| Database | Supabase PostgreSQL with Row Level Security |
| ML Service | Python, Flask, scikit-learn, XGBoost, LightGBM, Sentence-BERT, SHAP |
| Passenger App | Flutter, Provider, FlutterMap |
| Driver App | Flutter, Provider, Geolocator |
| Scanner App | Flutter |
| Admin Panel | React, TypeScript, Vite, Leaflet |
| Maps | MapTiler Streets v2 |
| Real-time | Supabase Realtime (broadcast channels) |
| Auth | JWT (backend-issued tokens) |

## Database Schema (Key Tables)

| Table | Description |
|-------|-------------|
| `buses` | Bus status, GPS coordinates, speed, crowd level, driver assignment |
| `bus_routes` | 28 routes with origin, destination, color coding |
| `bus_stops` | 372 stops (323 real Colombo OSM stops + 49 non-Colombo) |
| `bus_stop_routes` | Route-to-stop mapping with stop ordering |
| `users` | Passengers, drivers, admins, scanners |
| `trips` | Active and completed trips with boarding/alighting times |
| `ratings` | Passenger ratings with ML-generated scores |

## Setup & Running

### Prerequisites
- Node.js (v18+)
- Python 3.9+ with Conda
- Flutter SDK (stable channel)
- Supabase project with credentials in `.env` files

### 1. Backend API
```bash
cd backend
npm install
npm start
# Runs on port 5000
```

### 2. ML Service
```bash
conda activate busgo
cd ml_service
python app.py
# Runs on port 8000 (may take 30-60s to load SBERT model)
```

### 3. Admin Panel
```bash
cd frontend/busgo_admin
npm install
npm run dev
# Opens at http://localhost:5173
```

### 4. Flutter Apps
```bash
# Passenger App
cd frontend/busgo_client
flutter pub get
flutter run --release

# Driver App
cd frontend/busgo_drive
flutter pub get
flutter run --release

# Scanner App
cd frontend/busgo_scanner
flutter pub get
flutter run --release
```

## How the Driver Toggle System Works

The core real-time tracking relies on a toggle mechanism:

1. **Driver toggles ON** → GPS starts → Backend API sets bus to `active` → Location updates stream every 10 seconds
2. **Passenger app polls** every 10 seconds for nearby active buses with fresh GPS data
3. **Driver toggles OFF** → GPS stops → Backend API sets bus to `inactive` with NULL coordinates → Bus disappears from all maps

The Drive app communicates through the **Backend API** (not Supabase directly) because the backend uses the service role key to bypass Row Level Security on the buses table.

### Three Safety Nets Against Ghost Buses
1. **Immediate** — Coordinates set to NULL on toggle OFF (bus vanishes on next poll)
2. **2-minute staleness filter** — Buses with GPS older than 2 minutes are excluded
3. **Startup reset** — Bus always reset to inactive on app launch and login

## API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/login` | No | Login (returns JWT) |
| GET | `/api/buses/nearby` | No | Get nearby active buses |
| GET | `/api/eta/bus/:busId/stop/:stopId` | No | Get ML-powered ETA |
| PATCH | `/api/driver/status` | Driver | Set bus online/offline |
| PATCH | `/api/driver/location` | Driver | Update GPS coordinates |
| PATCH | `/api/driver/crowd` | Driver | Update crowd level |
| GET | `/api/admin/buses` | Admin | Get all buses (admin panel) |

## Environment Variables

Each component requires a `.env` file with the appropriate credentials:

- **Backend**: Supabase URL, service role key, JWT secret
- **ML Service**: Model paths, backend URL
- **Flutter Apps**: API base URL, Supabase URL, Supabase anon key, MapTiler key
- **Admin Panel**: Supabase URL, Supabase anon key, MapTiler key

> `.env` files are excluded from version control. Contact the project maintainer for credentials.

## Bus Stop Data

- **323 real Colombo bus stops** sourced from OpenStreetMap via Overpass API
- **49 non-Colombo stops** added manually (Kandy, Matara, Galle, Kurunegala, etc.)
- **28 routes** fully linked to stops with correct ordering via `bus_stop_routes` table
