import requests
import time

# Search for actual bus stops in Colombo district using OpenStreetMap
def get_bus_stops_in_area(area_name, lat, lng, radius_meters=15000):
    """
    Uses OSM Overpass API to find actual tagged bus stops in an area.
    This returns REAL bus stop locations, not just city centers.
    """
    overpass_url = "https://overpass-api.de/api/interpreter"
    
    # Query for bus stops within radius of center point
    query = f"""
    [out:json][timeout:30];
    (
      node["highway"="bus_stop"]
        (around:{radius_meters},{lat},{lng});
      node["public_transport"="stop_position"]
        (around:{radius_meters},{lat},{lng});
      node["public_transport"="platform"]
        (around:{radius_meters},{lat},{lng});
    );
    out body;
    """
    
    try:
        response = requests.post(
            overpass_url,
            data=query,
            headers={"User-Agent": "busgo-app/1.0"},
            timeout=30
        )
        data = response.json()
        return data.get("elements", [])
    except Exception as e:
        print(f"Error: {e}")
        return []

def clean_stop_name(tags):
    """Extract best available name from OSM tags."""
    name = (
        tags.get("name") or
        tags.get("name:en") or
        tags.get("ref") or
        tags.get("local_ref") or
        None
    )
    return name

# ── Main ───────────────────────────────────────────────────────────────────────
print("=" * 60)
print("  BUSGO — Fetching Real Colombo Bus Stops from OpenStreetMap")
print("=" * 60)
print()

# Colombo city center coordinates
COLOMBO_LAT = 6.9271
COLOMBO_LNG = 79.8612
RADIUS = 20000  # 20km radius covers greater Colombo

print(f"Searching for bus stops within {RADIUS/1000}km of Colombo...")
print()

stops = get_bus_stops_in_area("Colombo", COLOMBO_LAT, COLOMBO_LNG, RADIUS)

print(f"Found {len(stops)} raw OSM nodes")
print()

# Filter and clean
valid_stops = []
seen_names = set()

for stop in stops:
    tags = stop.get("tags", {})
    lat  = stop.get("lat")
    lng  = stop.get("lon")
    name = clean_stop_name(tags)
    
    if not name or not lat or not lng:
        continue
    
    # Skip duplicates
    name_key = name.lower().strip()
    if name_key in seen_names:
        continue
    seen_names.add(name_key)
    
    # Skip very short names (likely bad data)
    if len(name) < 3:
        continue
        
    valid_stops.append((name, lat, lng))

print(f"Valid named stops: {len(valid_stops)}")
print()

# Show preview
print("Sample stops found:")
for name, lat, lng in valid_stops[:10]:
    print(f"  • {name}: {lat:.6f}, {lng:.6f}")
print(f"  ... and {len(valid_stops) - 10} more")
print()

# Generate SQL
print("=" * 60)
print("  SQL OUTPUT — paste into Supabase")
print("=" * 60)
print()
print("INSERT INTO bus_stops (stop_name, latitude, longitude) VALUES")

sql_lines = []
for name, lat, lng in valid_stops:
    # Escape single quotes in names
    safe_name = name.replace("'", "''")
    sql_lines.append(f"  ('{safe_name}', {lat:.6f}, {lng:.6f})")

print(",\n".join(sql_lines))
print("ON CONFLICT DO NOTHING;")

print()
print("=" * 60)
print(f"  ✅ Total stops: {len(valid_stops)}")
print("=" * 60)