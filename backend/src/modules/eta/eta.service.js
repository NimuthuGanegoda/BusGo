import { supabase } from '../../config/supabase.js';
import { haversineKm } from '../../utils/haversine.utils.js';
import { predictETA } from '../../utils/ml.client.js';


// ── Open-Meteo weather check (free, no API key) ───────────────────────────────
// Returns 1 if raining, 0 if dry or if API is unavailable.
async function checkIsRaining(lat, lng) {
  try {
    const resp = await fetch(
      `https://api.open-meteo.com/v1/forecast` +
      `?latitude=${lat}&longitude=${lng}` +
      `&current=precipitation&timezone=Asia%2FColombo`,
      { signal: AbortSignal.timeout(3000) }
    );
    if (!resp.ok) return 0;
    const data   = await resp.json();
    const precip = data?.current?.precipitation ?? 0;
    return precip > 0 ? 1 : 0;
  } catch (_) {
    return 0;
  }
}

// ── Sri Lanka Public Holidays 2026 ────────────────────────────────────────────
const SL_PUBLIC_HOLIDAYS_2026 = new Set([
  '2026-01-14', '2026-01-15', '2026-02-04', '2026-02-13',
  '2026-02-14', '2026-03-15', '2026-04-03', '2026-04-13',
  '2026-04-14', '2026-05-01', '2026-05-12', '2026-05-13',
  '2026-06-11', '2026-07-10', '2026-08-09', '2026-09-08',
  '2026-10-07', '2026-10-20', '2026-11-06', '2026-12-05',
  '2026-12-25',
]);

function checkIsPublicHoliday() {
  const today = new Date().toISOString().slice(0, 10);
  return SL_PUBLIC_HOLIDAYS_2026.has(today) ? 1 : 0;
}
/**
 * Predict ETA for a bus to reach a specific stop.
 *
 * @param {string} busId
 * @param {string} targetStopId
 * @param {{ is_raining?: boolean }} context
 */
export async function getBusETA(busId, targetStopId, context = {}) {
  // 1. Get bus current position + route + speed
  const { data: bus, error: busErr } = await supabase
    .from('buses')
    .select('id, bus_number, current_lat, current_lng, speed_kmh, route_id, status')
    .eq('id', busId)
    .single();

  if (busErr || !bus) {
    const err = new Error('Bus not found'); err.statusCode = 404; err.code = 'BUS_NOT_FOUND'; throw err;
  }

  if (!bus.current_lat || !bus.current_lng) {
    const err = new Error('Bus location not available yet'); err.statusCode = 503; err.code = 'NO_BUS_LOCATION'; throw err;
  }

  // 2. Get target stop position
  const { data: stop, error: stopErr } = await supabase
    .from('bus_stops')
    .select('id, stop_name, latitude, longitude')
    .eq('id', targetStopId)
    .single();

  if (stopErr || !stop) {
    const err = new Error('Stop not found'); err.statusCode = 404; err.code = 'STOP_NOT_FOUND'; throw err;
  }

    // 4. Calculate straight-line distance (haversine)
  const dist_km = haversineKm(
    bus.current_lat, bus.current_lng,
    stop.latitude, stop.longitude
  );

  // 3. Count remaining stops between bus current pos and target
  const { data: routeStops } = await supabase
    .from('bus_stop_routes')
    .select('stop_order, bus_stops ( id, latitude, longitude )')
    .eq('route_id', bus.route_id)
    .order('stop_order');

  let stops_remaining = 3; // safe default
  if (routeStops && routeStops.length > 0) {
    // Find which stop the bus is currently closest to
    let busStopIdx = 0;
    let minDist    = Infinity;
    for (let i = 0; i < routeStops.length; i++) {
      const s = routeStops[i].bus_stops;
      if (!s?.latitude || !s?.longitude) continue;
      const d = haversineKm(bus.current_lat, bus.current_lng, s.latitude, s.longitude);
      if (d < minDist) { minDist = d; busStopIdx = i; }
    }
    // Count stops from bus position to target
    const targetStopIndex = routeStops.findIndex(s => s.bus_stops?.id === targetStopId);
    if (targetStopIndex > busStopIdx) {
      stops_remaining = targetStopIndex - busStopIdx;
    } else if (targetStopIndex === -1) {
      stops_remaining = Math.max(Math.round(dist_km / 0.5), 1);
    } else {
      stops_remaining = Math.max(routeStops.length - busStopIdx, 1);
    }
  }



  const hour            = new Date().getHours();
  const is_raining      = await checkIsRaining(bus.current_lat, bus.current_lng);
  const is_public_holiday = checkIsPublicHoliday();

  // 5. Call ML service
  const mlResult = await predictETA({
    bus_number:        bus.bus_number,
    dist_km,
    stops_remaining,
    speed_kmh:         bus.speed_kmh || 20,
    is_raining,
    is_public_holiday,
    hour,
  });

  return {
    bus_id:         busId,
    bus_number:     bus.bus_number,
    target_stop:    { id: stop.id, name: stop.stop_name },
    distance_km:    Math.round(dist_km * 100) / 100,
    stops_remaining,
    eta_minutes:    mlResult.eta_minutes,
    eta_seconds:    mlResult.eta_seconds,
    context:        mlResult.context,
    calculated_at:  new Date().toISOString(),
  };
}

/**
 * Get ETA for all buses on a route to a specific stop.
 *
 * @param {string} routeId
 * @param {string} targetStopId
 * @param {object} context
 */
export async function getRouteETAs(routeId, targetStopId, context = {}) {
  const { data: buses } = await supabase
    .from('buses')
    .select('id')
    .eq('route_id', routeId)
    .eq('status', 'active')
    .not('current_lat', 'is', null);

  if (!buses?.length) return [];

  const results = await Promise.allSettled(
    buses.map(b => getBusETA(b.id, targetStopId, context))
  );

  return results
    .filter(r => r.status === 'fulfilled')
    .map(r => r.value)
    .sort((a, b) => a.eta_minutes - b.eta_minutes);
}








