import { supabase } from '../../config/supabase.js';
import { buildPagination } from '../../utils/response.utils.js';

/**
 * Return paginated trip history for the authenticated user.
 *
 * @param {string} userId
 * @param {{ status?, from?, to?, page, page_size }} filters
 * @returns {{ trips: Array<object>, pagination: object }}
 */
export async function listTrips(userId, filters) {
  const { status, from, to, page, page_size } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('trips')
    .select(`
      id, status, boarded_at, alighted_at, fare_lkr, created_at,
      buses ( id, bus_number, driver_name ),
      bus_routes ( id, route_number, route_name, origin, destination, color ),
      boarding_stop:boarding_stop_id ( id, stop_name ),
      alighting_stop:alighting_stop_id ( id, stop_name ),
      ratings ( stars, tags, comment )
    `, { count: 'exact' })
    .eq('user_id', userId)
    .order('boarded_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (status) query = query.eq('status', status);
  if (from)   query = query.gte('boarded_at', from);
  if (to)     query = query.lte('boarded_at', to);

  const { data, error, count } = await query;
  if (error) throw error;

  return {
    trips: data,
    pagination: buildPagination(count, page, page_size),
  };
}

/**
 * Fetch a single trip by ID (must belong to the user).
 *
 * @param {string} tripId
 * @param {string} userId
 * @returns {object}
 */
export async function getTripById(tripId, userId) {
  const { data, error } = await supabase
    .from('trips')
    .select(`
      id, status, boarded_at, alighted_at, fare_lkr, created_at,
      buses ( id, bus_number, driver_name, driver_phone ),
      bus_routes ( id, route_number, route_name, origin, destination, color, waypoints ),
      boarding_stop:boarding_stop_id ( id, stop_name, latitude, longitude ),
      alighting_stop:alighting_stop_id ( id, stop_name, latitude, longitude ),
      ratings ( id, stars, tags, comment, created_at )
    `)
    .eq('id', tripId)
    .eq('user_id', userId)
    .single();

  if (error || !data) {
    const err = new Error('Trip not found');
    err.statusCode = 404;
    err.code = 'TRIP_NOT_FOUND';
    throw err;
  }
  return data;
}

/**
 * Create a new trip record (passenger boards bus).
 *
 * @param {string} userId
 * @param {{ bus_id, route_id, boarding_stop_id? }} dto
 * @returns {object} Created trip
 */
export async function createTrip(userId, dto) {
  // Verify no ongoing trip exists
  const { data: existing } = await supabase
    .from('trips')
    .select('id')
    .eq('user_id', userId)
    .eq('status', 'ongoing')
    .maybeSingle();

  if (existing) {
    const err = new Error('You already have an ongoing trip. Please exit the current bus first.');
    err.statusCode = 409;
    err.code = 'TRIP_ALREADY_ONGOING';
    throw err;
  }

  const { data, error } = await supabase
    .from('trips')
    .insert({
      user_id: userId,
      bus_id: dto.bus_id,
      route_id: dto.route_id,
      boarding_stop_id: dto.boarding_stop_id || null,
      status: 'ongoing',
    })
    .select(`
      id, status, boarded_at,
      buses ( bus_number, driver_name ),
      bus_routes ( route_number, route_name )
    `)
    .single();

  if (error) throw error;

  // Create a "trip started" notification
  await supabase.from('notifications').insert({
    user_id: userId,
    category: 'trip',
    title: 'Trip Started',
    body: `You have boarded bus ${data.buses?.bus_number} on route ${data.bus_routes?.route_number}.`,
    meta: { trip_id: data.id },
  });

  return data;
}

/**
 * Mark a trip as completed (passenger alights).
 *
 * @param {string} tripId
 * @param {string} userId
 * @param {{ alighting_stop_id?, fare_lkr? }} dto
 * @returns {object} Updated trip
 */
export async function alightTrip(tripId, userId, dto) {
  const { data: trip } = await supabase
    .from('trips')
    .select('id, status')
    .eq('id', tripId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!trip) {
    const err = new Error('Trip not found');
    err.statusCode = 404;
    err.code = 'TRIP_NOT_FOUND';
    throw err;
  }

  if (trip.status !== 'ongoing') {
    const err = new Error(`Cannot alight a trip with status: ${trip.status}`);
    err.statusCode = 409;
    err.code = 'TRIP_NOT_ONGOING';
    throw err;
  }

  const { data, error } = await supabase
    .from('trips')
    .update({
      status: 'completed',
      alighted_at: new Date().toISOString(),
      alighting_stop_id: dto.alighting_stop_id || null,
      fare_lkr: dto.fare_lkr || null,
    })
    .eq('id', tripId)
    .select('id, status, boarded_at, alighted_at, fare_lkr')
    .single();

  if (error) throw error;
  return data;
}
