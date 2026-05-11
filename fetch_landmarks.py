import requests
import json
import urllib.parse

def fetch_colombo_landmarks():
    query = """
[out:json][timeout:60];
(
  node["name"]["amenity"~"hospital|school|university|college|shopping_mall|park|cinema|stadium|museum|library|pharmacy|bank|supermarket|marketplace|theatre|bus_station|police|fire_station|community_centre|place_of_worship|hotel"](around:25000,6.9344,79.8428);
  node["name"]["tourism"~"attraction|museum|viewpoint|hotel|guest_house"](around:25000,6.9344,79.8428);
  node["name"]["railway"="station"](around:25000,6.9344,79.8428);
);
out body;
"""

    print("Fetching landmarks from Overpass API...")

    encoded = urllib.parse.quote(query)
    url = f"https://overpass-api.de/api/interpreter?data={encoded}"

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*',
    }

    try:
        response = requests.get(url, headers=headers, timeout=90)
        print(f"Status: {response.status_code}")
    except Exception as e:
        print(f"Request failed: {e}")
        # Fallback to alternative mirror
        try:
            url2 = f"https://overpass.kumi.systems/api/interpreter?data={encoded}"
            response = requests.get(url2, headers=headers, timeout=90)
            print(f"Mirror status: {response.status_code}")
        except Exception as e2:
            print(f"Mirror also failed: {e2}")
            return

    if response.status_code != 200:
        print(f"Error body: {response.text[:200]}")
        return

    data = response.json()
    elements = data.get("elements", [])
    print(f"Found {len(elements)} raw elements")

    landmarks = {}
    for el in elements:
        tags = el.get("tags", {})
        name = tags.get("name", "").strip()
        if not name or len(name) < 3:
            continue
        lat = el.get("lat")
        lng = el.get("lon")
        if lat is None or lng is None:
            continue
        amenity = (
            tags.get("amenity") or
            tags.get("tourism") or
            tags.get("shop") or
            tags.get("railway") or
            "place"
        )
        if name not in landmarks:
            landmarks[name] = {
                "name": name,
                "amenity": amenity,
                "lat": round(lat, 6),
                "lng": round(lng, 6),
            }

    print(f"Unique landmarks: {len(landmarks)}")

    print("\n\n// ── PASTE THIS INTO route_search_screen.dart ──")
    print("const allLandmarks = [")
    for lm in sorted(landmarks.values(), key=lambda x: x["name"]):
        name    = lm["name"].replace("'", "\\'").replace('"', '\\"')
        amenity = lm["amenity"]
        lat     = lm["lat"]
        lng     = lm["lng"]
        print(f"  {{'name': '{name}', 'amenity': '{amenity}', 'lat': {lat}, 'lng': {lng}}},")
    print("];")
    print(f"\n// Total: {len(landmarks)} landmarks")

if __name__ == "__main__":
    fetch_colombo_landmarks()