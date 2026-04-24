#!/usr/bin/env python3
"""
BUSGO — Bus Stop → Route Assignment Script
==========================================
Assigns unlinked bus stops to routes based on GPS proximity.
A stop is assigned to ALL routes it falls within the distance threshold of
(realistic — Colombo stops often serve multiple routes).

After assignment, stop_order is recalculated geographically for every
affected route so the sequence correctly reflects road order.

Usage
-----
1. pip install supabase
2. Set SUPABASE_URL and SUPABASE_KEY below (use service_role key)
3. Run with DRY_RUN = True first to preview assignments
4. Review the output, then set DRY_RUN = False to commit

Requirements: Python 3.10+, supabase>=2.0
"""

import math
import uuid
import os
from supabase import create_client, Client

# ── Configuration — edit these ────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL", "https://jgsjedkakwczclpuwcxs.supabase.co")
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impnc2plZGtha3djemNscHV3Y3hzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTgxNjQwNSwiZXhwIjoyMDkxMzkyNDA1fQ.q-fraK7_UUNfXtk4BMvNl2JdezyFvblwcI6lHTJ0RUg")  # NOT anon key

DISTANCE_THRESHOLD_KM = 0.75   # 750 m — stop must be within this to be assigned
DRY_RUN               = False   # Set False to actually write to database
BATCH_SIZE            = 50     # Rows per Supabase insert batch
# ─────────────────────────────────────────────────────────────────────────────


# ── Geometry helpers ──────────────────────────────────────────────────────────

def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Straight-line distance in km between two GPS coordinates."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(min(1.0, a)))


def point_to_segment(plat: float, plng: float,
                     alat: float, alng: float,
                     blat: float, blng: float) -> tuple[float, float]:
    """
    Perpendicular distance from point P to line segment A→B.
    Returns (distance_km, t) where t ∈ [0,1] is the fractional
    position along A→B of the closest point.
    """
    dx = blng - alng
    dy = blat - alat
    seg_sq = dx * dx + dy * dy

    if seg_sq < 1e-14:                          # degenerate (A == B)
        return haversine(plat, plng, alat, alng), 0.0

    t = ((plng - alng) * dx + (plat - alat) * dy) / seg_sq
    t = max(0.0, min(1.0, t))

    closest_lat = alat + t * (blat - alat)
    closest_lng = alng + t * (blng - alng)
    return haversine(plat, plng, closest_lat, closest_lng), t


def nearest_point_on_route(stop_lat: float, stop_lng: float,
                            waypoints: list[dict]) -> tuple[float, float]:
    """
    Find the minimum distance from a stop to any segment of a route polyline.
    Returns:
      - min_dist_km  : closest approach in km
      - route_pos_km : cumulative km from route start to that point
                       (used to sort stops in geographic order)
    """
    if len(waypoints) < 2:
        d = haversine(stop_lat, stop_lng,
                      waypoints[0]["lat"], waypoints[0]["lng"])
        return d, 0.0

    min_dist    = float("inf")
    best_pos_km = 0.0
    cum_km      = 0.0

    for i in range(len(waypoints) - 1):
        a = waypoints[i]
        b = waypoints[i + 1]
        seg_km = haversine(a["lat"], a["lng"], b["lat"], b["lng"])

        dist, t = point_to_segment(
            stop_lat, stop_lng,
            a["lat"],  a["lng"],
            b["lat"],  b["lng"],
        )

        if dist < min_dist:
            min_dist    = dist
            best_pos_km = cum_km + t * seg_km

        cum_km += seg_km

    return min_dist, best_pos_km


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("=" * 62)
    print("  BUSGO — Bus Stop Route Assignment")
    print(f"  Mode      : {'DRY RUN  (no writes)' if DRY_RUN else '🔴  LIVE WRITE'}")
    print(f"  Threshold : {DISTANCE_THRESHOLD_KM * 1000:.0f} m")
    print("=" * 62)

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # ── Load data ─────────────────────────────────────────────────────────────
    print("\n[1/5] Loading data from Supabase...")

    stops_res   = (supabase.table("bus_stops")
                           .select("id, stop_name, latitude, longitude")
                           .execute())
    all_stops   = stops_res.data
    print(f"      {len(all_stops)} bus stops loaded")

    routes_res  = (supabase.table("bus_routes")
                           .select("id, route_number, route_name, waypoints")
                           .eq("is_active", True)
                           .execute())
    all_routes  = [r for r in routes_res.data
                   if r.get("waypoints") and len(r["waypoints"]) >= 2]
    print(f"      {len(all_routes)} active routes with waypoints loaded")

    links_res   = (supabase.table("bus_stop_routes")
                           .select("id, stop_id, route_id, stop_order")
                           .execute())
    all_links   = links_res.data
    print(f"      {len(all_links)} existing stop-route links loaded")

    # ── Identify unlinked stops ───────────────────────────────────────────────
    linked_stop_ids = {lnk["stop_id"] for lnk in all_links}
    unlinked_stops  = [s for s in all_stops
                       if s["id"] not in linked_stop_ids
                       and s["latitude"] and s["longitude"]]
    print(f"\n      {len(linked_stop_ids)} stops already linked")
    print(f"      {len(unlinked_stops)} stops unlinked  ← will process these")

    # ── Build per-route lookup of existing links ──────────────────────────────
    # route_id → [ {id, stop_id, stop_order} ]
    existing_by_route: dict[str, list] = {}
    for lnk in all_links:
        existing_by_route.setdefault(lnk["route_id"], []).append(lnk)

    # stop_id → {id, lat, lng, name}
    stop_lookup = {s["id"]: s for s in all_stops}

    # ── Step 2: Match unlinked stops to routes ────────────────────────────────
    print("\n[2/5] Matching stops to routes by proximity...")

    # new_by_route[route_id] = list of { stop_id, stop_name, route_pos_km, dist_m }
    new_by_route: dict[str, list] = {}
    unmatched_count = 0
    matched_count   = 0

    for stop in unlinked_stops:
        slat, slng  = stop["latitude"], stop["longitude"]
        assignments = []

        for route in all_routes:
            dist_km, pos_km = nearest_point_on_route(slat, slng, route["waypoints"])
            if dist_km <= DISTANCE_THRESHOLD_KM:
                assignments.append({
                    "route_id":    route["id"],
                    "route_num":   route["route_number"],
                    "route_pos_km": pos_km,
                    "dist_m":      round(dist_km * 1000),
                })

        if not assignments:
            unmatched_count += 1
            continue

        matched_count += len(assignments)
        for a in assignments:
            new_by_route.setdefault(a["route_id"], []).append({
                "stop_id":      stop["id"],
                "stop_name":    stop["stop_name"],
                "route_pos_km": a["route_pos_km"],
                "dist_m":       a["dist_m"],
            })

    print(f"      {matched_count} new stop-route assignments found")
    print(f"      {unmatched_count} stops not within threshold of any route  (kept unlinked)")

    # ── Step 3: Recalculate stop_order for every affected route ───────────────
    print("\n[3/5] Recalculating stop order for affected routes...")

    # rows to INSERT  → list of {id, stop_id, route_id, stop_order}
    insert_rows: list[dict] = []
    # rows to UPDATE  → list of {id, stop_order}
    update_rows: list[dict] = []

    affected_route_ids = set(new_by_route.keys())

    for route in all_routes:
        rid = route["id"]
        if rid not in affected_route_ids:
            continue

        wps = route["waypoints"]

        # Existing stops on this route — calculate their route position
        existing_entries = []
        for lnk in existing_by_route.get(rid, []):
            s = stop_lookup.get(lnk["stop_id"])
            if not s:
                continue
            _, pos = nearest_point_on_route(s["latitude"], s["longitude"], wps)
            existing_entries.append({
                "stop_id":      s["id"],
                "stop_name":    s["stop_name"],
                "route_pos_km": pos,
                "existing":     True,
                "link_id":      lnk["id"],
                "old_order":    lnk["stop_order"],
            })

        # New stops to add
        new_entries = [{
            "stop_id":      n["stop_id"],
            "stop_name":    n["stop_name"],
            "route_pos_km": n["route_pos_km"],
            "existing":     False,
        } for n in new_by_route[rid]]

        # Merge and sort by geographic position along route
        combined = sorted(existing_entries + new_entries,
                          key=lambda x: x["route_pos_km"])

        print(f"\n  Route {route['route_number']:>4} — {route['route_name']}")
        print(f"           {len(existing_entries)} existing + {len(new_entries)} new = {len(combined)} total stops")

        for order, entry in enumerate(combined, start=1):
            tag   = "  "  if entry["existing"] else "➕"
            print(f"    {order:>3}. {tag} {entry['stop_name'][:45]}")

            if entry["existing"]:
                if entry["old_order"] != order:
                    update_rows.append({"id": entry["link_id"], "stop_order": order})
            else:
                insert_rows.append({
                    "id":         str(uuid.uuid4()),
                    "stop_id":    entry["stop_id"],
                    "route_id":   rid,
                    "stop_order": order,
                })

    # ── Step 4: Summary ───────────────────────────────────────────────────────
    print("\n" + "=" * 62)
    print("[4/5] Summary")
    print(f"      Routes affected          : {len(affected_route_ids)}")
    print(f"      New rows to INSERT       : {len(insert_rows)}")
    print(f"      Existing rows to UPDATE  : {len(update_rows)}")
    print(f"      Stops still unlinked     : {unmatched_count}")
    print("=" * 62)

    if DRY_RUN:
        print("\n✋  DRY RUN complete — nothing written to database.")
        print("   Review the output above, then set DRY_RUN = False and re-run.")
        return

    # ── Step 5: Write to database ─────────────────────────────────────────────
    print("\n[5/5] Writing to database...")

    # Insert new links in batches
    total_inserted = 0
    for i in range(0, len(insert_rows), BATCH_SIZE):
        batch = insert_rows[i : i + BATCH_SIZE]
        supabase.table("bus_stop_routes").insert(batch).execute()
        total_inserted += len(batch)
        print(f"      Inserted {total_inserted}/{len(insert_rows)} rows...")

    # Update stop_order on existing links
    total_updated = 0
    for row in update_rows:
        (supabase.table("bus_stop_routes")
                 .update({"stop_order": row["stop_order"]})
                 .eq("id", row["id"])
                 .execute())
        total_updated += 1

    print(f"\n✅  Done!")
    print(f"   {total_inserted} new stop-route links created")
    print(f"   {total_updated} existing stop orders corrected")
    print(f"\n   Reload the admin panel map to see the updated stops.")


if __name__ == "__main__":
    main()