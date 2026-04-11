import { supabase } from '../../config/supabase.js';
import { haversineKm } from '../../utils/haversine.utils.js';
import { predictETA } from '../../utils/ml.client.js';

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

  // 3. Count remaining stops between bus current pos and target
  const { data: routeStops } = await supabase
    .from('bus_stop_routes')
    .select('stop_order, bus_stops ( id, latitude, longitude )')
    .eq('route_id', bus.route_id)
    .order('stop_order');

  const targetStopIndex = routeStops?.findIndex(s => s.bus_stops?.id === targetStopId) ?? -1;
  let stops_remaining = Math.max(targetStopIndex, 0);

  // 4. Calculate straight-line distance (haversine)
  const dist_km = haversineKm(
    bus.current_lat, bus.current_lng,
    stop.latitude, stop.longitude
  );

  const hour = new Date().getHours();

  // 5. Call ML service
  const mlResult = await predictETA({
    bus_number:      bus.bus_number,
    dist_km,
    stops_remaining,
    speed_kmh:       bus.speed_kmh || 20,
    is_raining:      context.is_raining || false,
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
