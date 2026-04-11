import { supabase, broadcastToChannel } from '../../config/supabase.js';
import { filterByRadius } from '../../utils/haversine.utils.js';
import { CONSTANTS } from '../../config/constants.js';

/**
 * Return all active buses within the given radius, sorted by distance.
 *
 * @param {number} lat      - User latitude
 * @param {number} lng      - User longitude
 * @param {number} radius   - Search radius in km
 * @returns {Array<object>} Buses with distance_km field
 */
export async function getNearbyBuses(lat, lng, radius) {
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone,
      current_lat, current_lng, heading, speed_kmh,
      crowd_level, status, last_location_update,
      bus_routes ( id, route_number, route_name, origin, destination, color )
    `)
    .eq('status', 'active')
    .not('current_lat', 'is', null)
    .not('current_lng', 'is', null);

  if (error) throw error;

  return filterByRadius(data, lat, lng, radius, 'current_lat', 'current_lng');
}

/**
 * Fetch a single bus by ID with its route info.
 *
 * @param {string} busId
 * @returns {object} Bus record
 */
export async function getBusById(busId) {
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone,
      current_lat, current_lng, heading, speed_kmh,
      crowd_level, status, last_location_update, created_at,
      bus_routes ( id, route_number, route_name, origin, destination, color, waypoints )
    `)
    .eq('id', busId)
    .single();

  if (error || !data) {
    const err = new Error('Bus not found');
    err.statusCode = 404;
    err.code = 'BUS_NOT_FOUND';
    throw err;
  }
  return data;
}

/**
 * Update the GPS position of a bus and broadcast to Realtime subscribers.
 *
 * @param {string} busId
 * @param {{ lat, lng, heading?, speed_kmh? }} dto
 * @returns {object} Updated bus record
 */
export async function updateBusLocation(busId, dto) {
  const now = new Date().toISOString();

  const { data, error } = await supabase
    .from('buses')
    .update({
      current_lat: dto.lat,
      current_lng: dto.lng,
      heading: dto.heading ?? null,
      speed_kmh: dto.speed_kmh ?? null,
      last_location_update: now,
    })
    .eq('id', busId)
    .select('id, bus_number, current_lat, current_lng, heading, speed_kmh, crowd_level, status')
    .single();

  if (error) throw error;

  // Broadcast to Flutter subscribers
  await broadcastToChannel(CONSTANTS.REALTIME_CHANNEL_BUS_LOCATIONS, 'location-update', {
    bus_id: busId,
    lat: dto.lat,
    lng: dto.lng,
    heading: dto.heading,
    speed_kmh: dto.speed_kmh,
    timestamp: now,
  });

  return data;
}

/**
 * Update the crowd level reported by a driver.
 *
 * @param {string} busId
 * @param {'low'|'medium'|'high'|'full'} crowd_level
 * @returns {object} Updated bus record
 */
export async function updateBusCrowd(busId, crowd_level) {
  const { data, error } = await supabase
    .from('buses')
    .update({ crowd_level })
    .eq('id', busId)
    .select('id, bus_number, crowd_level')
    .single();

  if (error) throw error;
  return data;
}
