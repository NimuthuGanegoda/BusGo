// driver.service.js
import { supabase, broadcastToChannel } from '../../config/supabase.js';
import { CONSTANTS } from '../../config/constants.js';

export async function getDriverProfile(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, username, phone, avatar_url, role, is_active, created_at')
    .eq('id', userId)
    .eq('role', 'driver')
    .single();

  if (error || !data) {
    const err = new Error('Driver profile not found'); err.statusCode = 404; err.code = 'DRIVER_NOT_FOUND'; throw err;
  }
  return data;
}

export async function getAssignedBus(userId) {
  // Drivers are linked to a bus by driver_user_id field
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone, current_lat, current_lng,
      heading, speed_kmh, crowd_level, status, last_location_update,
      bus_routes ( id, route_number, route_name, origin, destination, color, waypoints ),
      bus_routes ( bus_stop_routes ( stop_order, bus_stops ( id, stop_name, latitude, longitude ) ) )
    `)
    .eq('driver_user_id', userId)
    .eq('status', 'active')
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function updateDriverLocation(userId, dto) {
  // Find bus assigned to driver
  const { data: bus } = await supabase
    .from('buses')
    .select('id')
    .eq('driver_user_id', userId)
    .maybeSingle();

  if (!bus) {
    const err = new Error('No active bus assigned to this driver');
    err.statusCode = 404; err.code = 'NO_BUS_ASSIGNED'; throw err;
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('buses')
    .update({
      current_lat: dto.lat, current_lng: dto.lng,
      heading: dto.heading ?? null,
      speed_kmh: dto.speed_kmh ?? null,
      last_location_update: now,
    })
    .eq('id', bus.id)
    .select('id, bus_number, current_lat, current_lng, heading, speed_kmh')
    .single();

  if (error) throw error;

  // Broadcast to all Flutter passenger subscribers
  await broadcastToChannel(CONSTANTS.REALTIME_CHANNEL_BUS_LOCATIONS, 'location-update', {
    bus_id: bus.id, lat: dto.lat, lng: dto.lng,
    heading: dto.heading, speed_kmh: dto.speed_kmh, timestamp: now,
  });

  return data;
}

export async function updateCrowdLevel(userId, crowd_level) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();

  if (!bus) {
    const err = new Error('No active bus assigned'); err.statusCode = 404; err.code = 'NO_BUS_ASSIGNED'; throw err;
  }

  const { data, error } = await supabase
    .from('buses').update({ crowd_level }).eq('id', bus.id)
    .select('id, bus_number, crowd_level').single();

  if (error) throw error;
  return data;
}

export async function getDriverRating(userId) {
  // Get the bus this driver is assigned to
  const { data: bus } = await supabase
    .from('buses').select('id, bus_number').eq('driver_user_id', userId).maybeSingle();

  if (!bus) return { bus: null, total_ratings: 0, average_stars: null, average_ml_rating: null, star_breakdown: {} };

  const { data: ratings, error } = await supabase
    .from('ratings')
    .select('stars, ml_rating, comment, created_at')
    .eq('bus_id', bus.id)
    .order('created_at', { ascending: false });

  if (error) throw error;

  const total = ratings.length;
  const avg_stars = total > 0 ? +(ratings.reduce((s, r) => s + r.stars, 0) / total).toFixed(2) : null;
  const ml_ratings = ratings.filter(r => r.ml_rating !== null);
  const avg_ml = ml_ratings.length > 0 ? +(ml_ratings.reduce((s, r) => s + r.ml_rating, 0) / ml_ratings.length).toFixed(2) : null;
  const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  ratings.forEach(r => { breakdown[r.stars] = (breakdown[r.stars] || 0) + 1; });

  return {
    bus,
    total_ratings: total,
    average_stars: avg_stars,
    average_ml_rating: avg_ml,
    star_breakdown: breakdown,
    recent_comments: ratings.slice(0, 5).map(r => ({ comment: r.comment, stars: r.stars, ml_rating: r.ml_rating, date: r.created_at })),
  };
}

export async function getDriverCurrentTrip(userId) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();

  if (!bus) return null;

  const { data, error } = await supabase
    .from('trips')
    .select(`
      id, status, boarded_at,
      users ( id, full_name, username ),
      bus_routes ( route_number, route_name ),
      boarding_stop:boarding_stop_id ( stop_name )
    `)
    .eq('bus_id', bus.id)
    .eq('status', 'ongoing')
    .order('boarded_at', { ascending: false });

  if (error) throw error;
  return { bus_id: bus.id, active_passengers: data?.length || 0, trips: data };
}
