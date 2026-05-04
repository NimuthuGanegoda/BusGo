// BUSGO — Auto-assign bus stops to routes
// Run: node assign_stops.js
// Requires: npm install @supabase/supabase-js

import { createClient } from '@supabase/supabase-js';
import { supabase } from './src/config/supabase.js';

// ── CONFIG — paste your Supabase URL and service role key ─────────────────
const RADIUS_METERS     = 80;
const MIN_CONSECUTIVE   = 2;
// ─────────────────────────────────────────────────────────────────────────



function haversineMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 +
            Math.cos(lat1 * Math.PI/180) * Math.cos(lat2 * Math.PI/180) *
            Math.sin(dLng/2)**2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

async function assignStopsToRoute(route, stops) {
  const waypoints = route.waypoints;
  if (!waypoints || waypoints.length === 0) {
    console.log(`  ⚠ Route ${route.route_number} has no waypoints — skipping`);
    return 0;
  }

  const qualified = [];

  for (const stop of stops) {
    const sLat = stop.latitude;
    const sLng = stop.longitude;

    // Quick bounding box pre-filter — skip if stop is far from route bbox
    const lats = waypoints.map(w => w.lat);
    const lngs = waypoints.map(w => w.lng);
    const minLat = Math.min(...lats) - 0.002;
    const maxLat = Math.max(...lats) + 0.002;
    const minLng = Math.min(...lngs) - 0.002;
    const maxLng = Math.max(...lngs) + 0.002;
    if (sLat < minLat || sLat > maxLat || sLng < minLng || sLng > maxLng) continue;

    // Consecutive waypoint check
    let consec = 0;
    let bestWpIndex = -1;
    let bestDist = Infinity;

    for (let i = 0; i < waypoints.length; i++) {
      const dist = haversineMeters(sLat, sLng, waypoints[i].lat, waypoints[i].lng);

      if (dist <= RADIUS_METERS) {
        consec++;
        if (dist < bestDist) {
          bestDist = dist;
          bestWpIndex = i;
        }
        if (consec >= MIN_CONSECUTIVE) break; // confirmed
      } else {
        consec = 0; // reset — must be consecutive
      }
    }

    if (consec >= MIN_CONSECUTIVE) {
      qualified.push({ stopId: stop.id, wpIndex: bestWpIndex, dist: bestDist });
    }
  }

  // Sort by position along route
  qualified.sort((a, b) => a.wpIndex - b.wpIndex);

  if (qualified.length === 0) {
    console.log(`  Route ${route.route_number}: 0 stops found`);
    return 0;
  }

  // Delete existing stops for this route
  await supabase.from('bus_stop_routes').delete().eq('route_id', route.id);

  // Insert in batches of 50
  const rows = qualified.map((q, i) => ({
    route_id:   route.id,
    stop_id:    q.stopId,
    stop_order: i + 1,
  }));

  for (let i = 0; i < rows.length; i += 50) {
    const batch = rows.slice(i, i + 50);
    const { error } = await supabase.from('bus_stop_routes').insert(batch);
    if (error) console.error(`  ❌ Insert error:`, error.message);
  }

  console.log(`  ✅ Route ${route.route_number} (${route.route_name}): ${rows.length} stops assigned`);
  return rows.length;
}

async function main() {
  console.log('🚌 BUSGO Stop Auto-Assignment\n');

  // Fetch all routes with waypoints
  const { data: routes, error: rErr } = await supabase
    .from('bus_routes')
    .select('id, route_number, route_name, waypoints')
    .order('route_number');
  if (rErr) { console.error('Failed to fetch routes:', rErr.message); process.exit(1); }

  // Fetch all bus stops
  const { data: stops, error: sErr } = await supabase
    .from('bus_stops')
    .select('id, stop_name, latitude, longitude');
  if (sErr) { console.error('Failed to fetch stops:', sErr.message); process.exit(1); }

  console.log(`Found ${routes.length} routes and ${stops.length} stops\n`);

  let totalAssigned = 0;
  for (const route of routes) {
    process.stdout.write(`Processing Route ${route.route_number}...`);
    const count = await assignStopsToRoute(route, stops);
    totalAssigned += count;
  }

  console.log(`\n✅ Done! ${totalAssigned} total stop assignments across ${routes.length} routes`);
}

main().catch(console.error);
