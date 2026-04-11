import { supabase } from '../../config/supabase.js';
import { filterByRadius } from '../../utils/haversine.utils.js';

/**
 * Return all bus stops.
 *
 * @returns {Array<object>}
 */
export async function getAllStops() {
  const { data, error } = await supabase
    .from('bus_stops')
    .select('id, stop_name, latitude, longitude')
    .order('stop_name');

  if (error) throw error;
  return data;
}

/**
 * Fetch a single stop by ID with its associated routes.
 *
 * @param {string} stopId
 * @returns {object}
 */
export async function getStopById(stopId) {
  const { data, error } = await supabase
    .from('bus_stops')
    .select(`
      id, stop_name, latitude, longitude, created_at,
      bus_stop_routes (
        stop_order,
        bus_routes ( id, route_number, route_name, origin, destination, color )
      )
    `)
    .eq('id', stopId)
    .single();

  if (error || !data) {
    const err = new Error('Stop not found');
    err.statusCode = 404;
    err.code = 'STOP_NOT_FOUND';
    throw err;
  }

  const routes = data.bus_stop_routes.map((r) => ({
    stop_order: r.stop_order,
    ...r.bus_routes,
  }));

  return { ...data, routes, bus_stop_routes: undefined };
}

/**
 * Return all stops within a given radius, sorted by distance ascending.
 *
 * @param {number} lat
 * @param {number} lng
 * @param {number} radius - km
 * @returns {Array<object & { distance_km: number }>}
 */
export async function getNearbyStops(lat, lng, radius) {
  const { data, error } = await supabase
    .from('bus_stops')
    .select('id, stop_name, latitude, longitude');

  if (error) throw error;

  return filterByRadius(data, lat, lng, radius);
}

/**
 * Return all routes passing through a given stop.
 *
 * @param {string} stopId
 * @returns {Array<object>}
 */
export async function getStopRoutes(stopId) {
  const { data, error } = await supabase
    .from('bus_stop_routes')
    .select(`
      stop_order,
      bus_routes ( id, route_number, route_name, origin, destination, color )
    `)
    .eq('stop_id', stopId)
    .order('stop_order');

  if (error) throw error;
  return data.map((r) => ({ stop_order: r.stop_order, ...r.bus_routes }));
}
