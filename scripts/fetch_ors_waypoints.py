#!/usr/bin/env python3
"""
BUSGO — Route Waypoints via OpenRouteService
=============================================
Fetches road-accurate GPS coordinates for all 28 routes using the
OpenRouteService Directions API (free tier: 2000 req/day).

Each route is defined by 2-5 key town coordinates. ORS returns
hundreds of actual road-following GPS points between them.
Results are saved back to Supabase bus_routes.waypoints column.

Usage
-----
1. pip install supabase requests
2. Fill in ORS_API_KEY, SUPABASE_URL, SUPABASE_KEY below
3. Set DRY_RUN = True first to test, then False to save to DB

Free tier limits: 2000 requests/day, 50 waypoints/request
This script makes 28 requests — well within limits.
"""

import time
import requests
import os
from supabase import create_client, Client

# ── Configuration — fill these in ────────────────────────────────────────────
ORS_API_KEY  = "eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijc2MmRkYjg5MGNkMTRhYTViNzRkZGIyNTJlM2ZmODUyIiwiaCI6Im11cm11cjY0In0="          # from openrouteservice.org
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://jgsjedkakwczclpuwcxs.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impnc2plZGtha3djemNscHV3Y3hzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTgxNjQwNSwiZXhwIjoyMDkxMzkyNDA1fQ.q-fraK7_UUNfXtk4BMvNl2JdezyFvblwcI6lHTJ0RUg")
DRY_RUN      = False    # Set False to actually save to Supabase
SLEEP_SEC    = 1.5     # Pause between ORS requests (be polite to free tier)
# ─────────────────────────────────────────────────────────────────────────────

ORS_URL = "https://api.openrouteservice.org/v2/directions/driving-car/geojson"

# ── Key waypoints per route ───────────────────────────────────────────────────
# Format: [longitude, latitude]  ← ORS uses lng,lat order (opposite of Leaflet)
# These are major towns ORS must route THROUGH.
# ORS fills in all the road geometry between them automatically.

ROUTES = [
    {
        "id":   "bc881a15-4a92-43fa-b998-9efeeab748da",
        "name": "Route 1 — Colombo Fort → Kandy",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.9583, 7.0004],   # Kadawatha
            [80.2089, 7.0486],   # Nittambuwa
            [80.3463, 7.2514],   # Kegalle
            [80.5942, 7.2569],   # Peradeniya
            [80.6337, 7.2906],   # Kandy
        ],
    },
    {
        "id":   "2fa5590b-5223-4d72-8412-7285e6a13471",
        "name": "Route 2 — Colombo Fort → Matara",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8820, 6.7729],   # Moratuwa
            [79.9607, 6.5854],   # Kalutara
            [80.0017, 6.4268],   # Aluthgama
            [80.1008, 6.1390],   # Hikkaduwa
            [80.2170, 6.0328],   # Galle
            [80.5550, 5.9549],   # Matara
        ],
    },
    {
        "id":   "ac0c8bde-f33f-4e5b-88e9-4ff665983d46",
        "name": "Route 3 — Colombo Fort → Kataragama",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.9607, 6.5854],   # Kalutara
            [80.2170, 6.0328],   # Galle
            [80.5550, 5.9549],   # Matara
            [80.7985, 6.0229],   # Tangalle
            [81.1185, 6.1241],   # Hambantota
            [81.2876, 6.2855],   # Tissamaharama
            [81.3338, 6.4142],   # Kataragama
        ],
    },
    {
        "id":   "3ceb35f0-1949-4593-a0dd-b402e4b539b7",
        "name": "Route 4 — Colombo Fort → Mannar",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.0128, 7.0875],   # Gampaha
            [80.3647, 7.4863],   # Kurunegala
            [80.4037, 8.3114],   # Anuradhapura
            [80.4972, 8.7514],   # Vavuniya
            [79.9044, 8.9810],   # Mannar
        ],
    },
    {
        "id":   "a8f568f5-59fc-447e-ab00-358489758fde",
        "name": "Route 5 — Colombo Fort → Kurunegala",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.9213, 6.9553],   # Kelaniya
            [80.0128, 7.0875],   # Gampaha
            [80.2878, 7.3244],   # Polgahawela
            [80.3647, 7.4863],   # Kurunegala
        ],
    },
    {
        "id":   "4d7cd23a-34d0-4cd2-9799-39b7e79bb75e",
        "name": "Route 6 — Colombo Fort → Kalpitiya",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8892, 7.0786],   # Ja-Ela
            [79.8378, 7.2096],   # Negombo
            [79.7950, 7.5759],   # Chilaw
            [79.8283, 8.0362],   # Puttalam
            [79.7444, 8.2278],   # Kalpitiya
        ],
    },
    {
        "id":   "672b276d-ebbd-4536-b12b-a3934dff288c",
        "name": "Route 7 — Colombo Fort → Matale",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
            [80.6234, 7.4698],   # Matale
        ],
    },
    {
        "id":   "b7525213-148d-432a-967e-992387e9a9c7",
        "name": "Route 8 — Colombo Fort → Theldeniya",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
            [80.7400, 7.2700],   # Theldeniya
        ],
    },
    {
        "id":   "f77b764a-6e48-4e3b-8849-0f64f5479a5f",
        "name": "Route 12 — Kandy → Monaragala",
        "via":  [
            [80.6337, 7.2906],   # Kandy
            [80.7400, 7.2700],   # Theldeniya
            [80.9981, 7.3295],   # Mahiyangana
            [81.2044, 7.1679],   # Bibile
            [81.3501, 6.8715],   # Monaragala
        ],
    },
    {
        "id":   "79fcb2fa-fd8b-432a-add7-037bcad9ce4f",
        "name": "Route 14 — Colombo Fort → Nawalapitiya",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
            [80.5766, 7.1642],   # Gampola
            [80.5328, 7.0553],   # Nawalapitiya
        ],
    },
    {
        "id":   "128ef7e4-387a-45af-9a7d-568c95fae226",
        "name": "Route 15 — Panadura → Kandy",
        "via":  [
            [79.9019, 6.7134],   # Panadura
            [80.0603, 6.7148],   # Horana
            [80.2143, 6.9527],   # Avissawella
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
        ],
    },
    {
        "id":   "e7af9c94-33a7-47a1-8ab9-02024a7ac812",
        "name": "Route 16 — Colombo Fort → Hatton",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
            [80.5766, 7.1642],   # Gampola
            [80.5328, 7.0553],   # Nawalapitiya
            [80.5957, 6.8921],   # Hatton
        ],
    },
    {
        "id":   "b9c8881e-9abd-4c90-9773-ea63cca15678",
        "name": "Route 17 — Colombo Fort → Gampola",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3463, 7.2514],   # Kegalle
            [80.6337, 7.2906],   # Kandy
            [80.5766, 7.1642],   # Gampola
        ],
    },
    {
        "id":   "fb37d9fa-cb4e-45ee-a844-3c9d4221e415",
        "name": "Route 22 — Badulla → Batticaloa",
        "via":  [
            [81.0552, 6.9934],   # Badulla
            [81.2300, 7.0300],   # Bibila area
            [81.6724, 7.2978],   # Ampara
            [81.6924, 7.7170],   # Batticaloa
        ],
    },
    {
        "id":   "50fd9f2d-263f-42ff-980a-d1d01b8e940c",
        "name": "Route 23 — Matara → Bandarawela",
        "via":  [
            [80.5550, 5.9549],   # Matara
            [80.3850, 6.1150],   # Akuressa area
            [80.5700, 6.3400],   # Deniyaya area
            [80.9554, 6.7667],   # Haputale
            [80.9895, 6.8289],   # Bandarawela
        ],
    },
    {
        "id":   "cc3e2939-8acd-40f4-a93a-238871539921",
        "name": "Route 26 — Galle → Ampara",
        "via":  [
            [80.2170, 6.0328],   # Galle
            [80.5550, 5.9549],   # Matara
            [80.7985, 6.0229],   # Tangalle
            [81.1185, 6.1241],   # Hambantota
            [81.0995, 6.7290],   # Wellawaya
            [81.3501, 6.8715],   # Monaragala
            [81.6724, 7.2978],   # Ampara
        ],
    },
    {
        "id":   "d8cea99b-7bed-4505-9fae-26bb97c4bf77",
        "name": "Route 33 — Colombo Fort → Kalmunai",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.6337, 7.2906],   # Kandy
            [80.9981, 7.3295],   # Mahiyangana
            [81.6724, 7.2978],   # Ampara
            [81.8261, 7.4073],   # Kalmunai
        ],
    },
    {
        "id":   "a723a8f9-f975-469f-8448-09935f1342d3",
        "name": "Route 34 — Colombo Fort → Trincomalee",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3647, 7.4863],   # Kurunegala
            [80.6511, 7.8742],   # Dambulla
            [80.7491, 8.0511],   # Habarana
            [81.2150, 8.5750],   # Trincomalee
        ],
    },
    {
        "id":   "99eb534c-68c3-48f9-ad1d-2e9d75d3f261",
        "name": "Route 36 — Colombo Fort → Anuradhapura",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [80.3647, 7.4863],   # Kurunegala
            [80.6511, 7.8742],   # Dambulla
            [80.4037, 8.3114],   # Anuradhapura
        ],
    },
    {
        "id":   "2f6b3edd-25b0-40ba-b269-2d271aa0ddbe",
        "name": "Route 40 — Kandy → Ratnapura",
        "via":  [
            [80.6337, 7.2906],   # Kandy
            [80.5942, 7.2569],   # Peradeniya
            [80.5328, 7.0553],   # Nawalapitiya
            [80.2143, 6.9527],   # Avissawella
            [80.3992, 6.6828],   # Ratnapura
        ],
    },
    {
        "id":   "476fef43-ef73-466b-bfe3-f1bb2c224d5c",
        "name": "Route 41 — Anuradhapura → Trincomalee",
        "via":  [
            [80.4037, 8.3114],   # Anuradhapura
            [80.5905, 8.0358],   # Kekirawa
            [80.7491, 8.0511],   # Habarana
            [81.2150, 8.5750],   # Trincomalee
        ],
    },
    {
        "id":   "1453c29b-a7fa-4bc3-b9ae-7ebf49b2b0ce",
        "name": "Route 100 — Colombo Fort → Panadura",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8656, 6.8528],   # Dehiwala
            [79.8820, 6.7729],   # Moratuwa
            [79.9019, 6.7134],   # Panadura
        ],
    },
    {
        "id":   "1a3aabf2-a493-4b3a-bf18-aeb3c2b6e1b6",
        "name": "Route 101 — Colombo Fort → Moratuwa",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8649, 6.8731],   # Dehiwala Junction
            [79.8656, 6.8528],   # Dehiwala
            [79.8645, 6.8373],   # Mount Lavinia
            [79.8820, 6.7729],   # Moratuwa
        ],
    },
    {
        "id":   "47092b7e-e9e8-42e2-bf50-84630c71299f",
        "name": "Route 120 — Colombo Fort → Matara (Express)",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8820, 6.7729],   # Moratuwa
            [79.9607, 6.5854],   # Kalutara
            [80.1008, 6.1390],   # Hikkaduwa
            [80.2170, 6.0328],   # Galle
            [80.5550, 5.9549],   # Matara
        ],
    },
    {
        "id":   "1abe0558-4664-4d72-8194-140ffda05f68",
        "name": "Route 138 — Colombo Fort → Kaduwela",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8912, 6.9093],   # Rajagiriya
            [79.9219, 6.8942],   # Battaramulla
            [79.9908, 6.9296],   # Kaduwela
        ],
    },
    {
        "id":   "b1f1d0f2-2803-43f5-9e98-d5639dfe963a",
        "name": "Route 177 — Colombo Fort → Kalutara",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8656, 6.8528],   # Dehiwala
            [79.8820, 6.7729],   # Moratuwa
            [79.9019, 6.7134],   # Panadura
            [79.9607, 6.5854],   # Kalutara
        ],
    },
    {
        "id":   "b639680d-72bc-439e-aaf6-16e956f3ecf0",
        "name": "Route 187 — Colombo Fort → Katunayake Airport",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8875, 6.9892],   # Wattala
            [79.8892, 7.0786],   # Ja-Ela
            [79.8864, 7.1698],   # Katunayake Airport
        ],
    },
    {
        "id":   "a46a1643-5b0c-43d3-8620-2f8cdd973fd6",
        "name": "Route 190 — Colombo Fort → Maharagama",
        "via":  [
            [79.8428, 6.9344],   # Colombo Fort
            [79.8912, 6.9093],   # Rajagiriya
            [79.8894, 6.8728],   # Nugegoda
            [79.9264, 6.8468],   # Maharagama
        ],
    },
]


# ── ORS API call ──────────────────────────────────────────────────────────────

def fetch_route_geometry(via_coords: list[list[float]]) -> list[dict] | None:
    """
    Call ORS Directions API and return waypoints as [{lat, lng}, ...].
    via_coords format: [[lng, lat], [lng, lat], ...]
    Returns None on failure.
    """
    headers = {
        "Authorization": ORS_API_KEY,
        "Content-Type":  "application/json",
    }
    body = {
        "coordinates": via_coords,
    }

    try:
        resp = requests.post(ORS_URL, json=body, headers=headers, timeout=15)
        resp.raise_for_status()
        data = resp.json()

        # ORS GeoJSON response: features[0].geometry.coordinates
        coords = data["features"][0]["geometry"]["coordinates"]

        # ORS returns [lng, lat] — convert to our {lat, lng} format
        return [{"lat": round(c[1], 6), "lng": round(c[0], 6)} for c in coords]

    except requests.exceptions.HTTPError as e:
        print(f"    ✗ HTTP error: {e.response.status_code} — {e.response.text[:200]}")
        return None
    except Exception as e:
        print(f"    ✗ Error: {e}")
        return None


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=" * 62)
    print("  BUSGO — Route Waypoints via OpenRouteService")
    print(f"  Mode : {'DRY RUN (no DB writes)' if DRY_RUN else '🔴 LIVE WRITE'}")
    print(f"  Routes to process : {len(ROUTES)}")
    print("=" * 62)

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    success = 0
    failed  = []

    for i, route in enumerate(ROUTES, start=1):
        print(f"\n[{i:>2}/{len(ROUTES)}] {route['name']}")
        print(f"       Calling ORS with {len(route['via'])} key waypoints...")

        waypoints = fetch_route_geometry(route["via"])

        if waypoints is None:
            print(f"       ✗ FAILED — skipping")
            failed.append(route["name"])
            time.sleep(SLEEP_SEC)
            continue

        print(f"       ✓ Got {len(waypoints)} road-accurate coordinates")

        if not DRY_RUN:
            supabase.table("bus_routes") \
                    .update({"waypoints": waypoints}) \
                    .eq("id", route["id"]) \
                    .execute()
            print(f"       ✓ Saved to Supabase")
        else:
            # Preview first and last 3 points
            sample = waypoints[:3] + [{"lat": "...", "lng": "..."}] + waypoints[-2:]
            print(f"       Preview: {sample}")

        success += 1
        time.sleep(SLEEP_SEC)   # be polite to the free tier

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 62)
    print(f"  Done! {success}/{len(ROUTES)} routes processed successfully")
    if failed:
        print(f"  Failed routes ({len(failed)}):")
        for f in failed:
            print(f"    - {f}")
    if DRY_RUN:
        print("\n  ✋ DRY RUN — nothing saved.")
        print("     Set DRY_RUN = False and re-run to save to Supabase.")
    else:
        print("\n  ✅ All waypoints saved!")
        print("     Hard-refresh your admin panel to see road-accurate routes.")
    print("=" * 62)


if __name__ == "__main__":
    main()