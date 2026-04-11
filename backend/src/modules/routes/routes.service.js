import { supabase } from '../../config/supabase.js';

/**
 * Return all active bus routes.
 *
 * @returns {Array<object>}
 */
export async function getAllRoutes() {
  const { data, error } = await supabase
    .from('bus_routes')
    .select('id, route_number, route_name, origin, destination, color, is_active, created_at')
    .eq('is_active', true)
    .order('route_number');

  if (error) throw error;
  return data;
}

/**
 * Fetch a single route by ID including its waypoints.
 *
 * @param {string} routeId
 * @returns {object}
 */
export async function getRouteById(routeId) {
  const { data, error } = await supabase
    .from('bus_routes')
    .select('*')
    .eq('id', routeId)
    .single();

  if (error || !data) {
    const err = new Error('Route not found');
    err.statusCode = 404;
    err.code = 'ROUTE_NOT_FOUND';
    throw err;
  }
  return data;
}

/**
 * Full-text search across route_number, route_name, origin, destination.
 *
 * @param {string} query
 * @returns {Array<object>}
 */
export async function searchRoutes(query) {
  const q = `%${query.toLowerCase()}%`;
  const { data, error } = await supabase
    .from('bus_routes')
    .select('id, route_number, route_name, origin, destination, color')
    .eq('is_active', true)
    .or(`route_number.ilike.${q},route_name.ilike.${q},origin.ilike.${q},destination.ilike.${q}`);

  if (error) throw error;
  return data;
}

/**
 * Get all stops along a given route, ordered by stop_order.
 *
 * @param {string} routeId
 * @returns {Array<object>}
 */
export async function getRouteStops(routeId) {
  const { data, error } = await supabase
    .from('bus_stop_routes')
    .select(`
      stop_order,
      bus_stops ( id, stop_name, latitude, longitude )
    `)
    .eq('route_id', routeId)
    .order('stop_order');

  if (error) throw error;
  return data.map((r) => ({ stop_order: r.stop_order, ...r.bus_stops }));
}

/**
 * Get all active buses currently operating on a given route.
 *
 * @param {string} routeId
 * @returns {Array<object>}
 */
export async function getRouteBuses(routeId) {
  const { data, error } = await supabase
    .from('buses')
    .select('id, bus_number, driver_name, current_lat, current_lng, heading, speed_kmh, crowd_level, status, last_location_update')
    .eq('route_id', routeId)
    .eq('status', 'active');

  if (error) throw error;
  return data;
}
