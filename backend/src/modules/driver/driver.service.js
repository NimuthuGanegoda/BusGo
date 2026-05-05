import { supabase, broadcastToChannel } from '../../config/supabase.js';
import { CONSTANTS } from '../../config/constants.js';

// ── FR-21: Haversine distance in km ──────────────────────────────────────────
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1 * Math.PI / 180)
    * Math.cos(lat2 * Math.PI / 180)
    * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.asin(Math.sqrt(a));
}

// ── FR-21: Auto-notify passengers when bus is within 150m of their destination
async function checkAndNotifyNearbyStops(busId, lat, lng) {
  // Get all ongoing trips that have a destination stop set
  const { data: trips } = await supabase
    .from('trips')
    .select(`
      id, user_id, alighting_stop_id,
      alighting_stop:alighting_stop_id ( id, stop_name, latitude, longitude )
    `)
    .eq('bus_id', busId)
    .eq('status', 'ongoing')
    .not('alighting_stop_id', 'is', null);

  if (!trips || trips.length === 0) return;

  const { data: busData } = await supabase
    .from('buses').select('bus_number').eq('id', busId).single();
  const busNumber = busData?.bus_number || 'Bus';

  const notificationsToSend = [];

  for (const trip of trips) {
    const stop = trip.alighting_stop;
    if (!stop?.latitude || !stop?.longitude) continue;

    // Check if bus is within 150m of this passenger's destination
    const dist = haversineKm(lat, lng, stop.latitude, stop.longitude);
    if (dist > 0.15) continue;

    // Prevent duplicate notifications for the same trip + stop
    const { data: existing } = await supabase
      .from('notifications')
      .select('id')
      .eq('user_id', trip.user_id)
      .eq('category', 'bus_alert')
      .contains('meta', { trip_id: trip.id, stop_id: stop.id })
      .maybeSingle();

    if (existing) continue;

    notificationsToSend.push({
      user_id:  trip.user_id,
      category: 'bus_alert',
      title:    '🚏 Your stop is approaching!',
      body:     `${busNumber} is arriving at ${stop.stop_name}. Please prepare to alight.`,
      meta:     { trip_id: trip.id, bus_id: busId, stop_id: stop.id, stop_name: stop.stop_name },
    });
  }

  if (notificationsToSend.length > 0) {
    await supabase.from('notifications').insert(notificationsToSend);
    console.log(`[FR-21] Notified ${notificationsToSend.length} passenger(s) approaching destination`);
  }
}

export async function getDriverProfile(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, username, phone, avatar_url, role, is_active, created_at')
    .eq('id', userId).eq('role', 'driver').single();
  if (error || !data) {
    const err = new Error('Driver profile not found');
    err.statusCode = 404; err.code = 'DRIVER_NOT_FOUND'; throw err;
  }
  return data;
}

export async function getAssignedBus(userId) {
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone, current_lat, current_lng,
      heading, speed_kmh, crowd_level, status, last_location_update,
      capacity, express_mode,
      bus_routes (
        id, route_number, route_name, origin, destination, color, waypoints,
        bus_stop_routes ( stop_order, bus_stops ( id, stop_name, latitude, longitude ) )
      )
    `)
    .eq('driver_user_id', userId).maybeSingle();
  if (error) throw error;
  console.log('[Bus Debug]', JSON.stringify(data)?.substring(0, 300));
  return data;
}

export async function updateDriverLocation(userId, dto) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();
  if (!bus) {
    const err = new Error('No active bus assigned to this driver');
    err.statusCode = 404; err.code = 'NO_BUS_ASSIGNED'; throw err;
  }
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('buses')
    .update({ current_lat: dto.lat, current_lng: dto.lng, heading: dto.heading ?? null,
              speed_kmh: dto.speed_kmh ?? null, last_location_update: now })
    .eq('id', bus.id)
    .select('id, bus_number, current_lat, current_lng, heading, speed_kmh')
    .single();
  if (error) throw error;

  await broadcastToChannel(CONSTANTS.REALTIME_CHANNEL_BUS_LOCATIONS, 'location-update', {
    bus_id: bus.id, lat: dto.lat, lng: dto.lng,
    heading: dto.heading, speed_kmh: dto.speed_kmh, timestamp: now,
  });

  // FR-21: fire-and-forget — never delays the GPS response to the driver app
  checkAndNotifyNearbyStops(bus.id, dto.lat, dto.lng).catch(err => {
    console.warn('[FR-21] Proximity check error:', err.message);
  });

  return data;
}

export async function updateCrowdLevel(userId, crowd_level) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();
  if (!bus) {
    const err = new Error('No active bus assigned');
    err.statusCode = 404; err.code = 'NO_BUS_ASSIGNED'; throw err;
  }
  const { data, error } = await supabase
    .from('buses').update({ crowd_level }).eq('id', bus.id)
    .select('id, bus_number, crowd_level').single();
  if (error) throw error;
  return data;
}

export async function updateDriverBusStatus(userId, status) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();
  if (!bus) {
    const err = new Error('No bus assigned to this driver');
    err.statusCode = 404; err.code = 'NO_BUS_ASSIGNED'; throw err;
  }
  const updateData = status === 'active'
    ? { status: 'active', last_location_update: new Date().toISOString() }
    : { status: 'inactive', current_lat: null, current_lng: null,
        last_location_update: null, speed_kmh: 0, express_mode: false };
  const { data, error } = await supabase
    .from('buses').update(updateData).eq('id', bus.id)
    .select('id, bus_number, status').single();
  if (error) throw error;
  return data;
}

export async function getDriverCurrentTrip(userId) {
  const { data: bus } = await supabase
    .from('buses').select('id, capacity, express_mode, crowd_level')
    .eq('driver_user_id', userId).maybeSingle();
  if (!bus) return null;
  const capacity = bus.capacity || 50;
  const { data, error } = await supabase
    .from('trips')
    .select(`
      id, status, boarded_at, alighting_stop_id,
      users ( id, full_name, username ),
      bus_routes ( route_number, route_name ),
      boarding_stop:boarding_stop_id ( stop_name ),
      alighting_stop:alighting_stop_id ( id, stop_name )
    `)
    .eq('bus_id', bus.id).eq('status', 'ongoing')
    .order('boarded_at', { ascending: false });
  if (error) throw error;
  const activePassengers = data?.length || 0;
  const shouldBeExpress = activePassengers >= capacity;
  if (bus.express_mode !== shouldBeExpress) {
    await supabase.from('buses').update({
      express_mode: shouldBeExpress,
      crowd_level: shouldBeExpress ? 'full'
        : activePassengers >= capacity * 0.75 ? 'high'
        : activePassengers >= capacity * 0.5  ? 'medium' : 'low',
    }).eq('id', bus.id);
  }
  const mustStopAt = (data || [])
    .filter(t => t.alighting_stop_id && t.alighting_stop?.stop_name)
    .reduce((acc, t) => {
      const id = t.alighting_stop_id;
      const name = t.alighting_stop?.stop_name;
      if (!acc.find(s => s.id === id)) acc.push({ id, name });
      return acc;
    }, []);
  return {
    bus_id: bus.id, active_passengers: activePassengers,
    bus_capacity: capacity, is_express_mode: shouldBeExpress,
    must_stop_at: mustStopAt,
    must_stop_at_ids: [...new Set((data||[]).filter(t=>t.alighting_stop_id).map(t=>t.alighting_stop_id))],
    trips: data,
  };
}

export async function getDriverRating(driverUserId) {
  const { data: bus } = await supabase
    .from('buses').select('id, bus_number').eq('driver_user_id', driverUserId).maybeSingle();
  if (!bus) return { overall_rating: 0, ml_rating: 0, total_reviews: 0,
    star_breakdown: {1:0,2:0,3:0,4:0,5:0}, recent_ratings: [], bus_number: null };
  const { data: ratings, error } = await supabase
    .from('ratings').select('id, stars, tags, comment, ml_rating, ml_confidence, ml_context, created_at')
    .eq('bus_id', bus.id).order('created_at', { ascending: false });
  if (error) throw error;
  const total = ratings?.length ?? 0;
  const star_breakdown = {1:0,2:0,3:0,4:0,5:0};
  let starSum=0, mlSum=0, mlCount=0;
  for (const r of ratings ?? []) {
    const s = Math.round(r.stars);
    if (s>=1&&s<=5) { star_breakdown[s]++; starSum+=s; }
    if (r.ml_rating!=null) { mlSum+=r.ml_rating; mlCount++; }
  }
  return {
    bus_number: bus.bus_number,
    overall_rating: total>0 ? Math.round((starSum/total)*10)/10 : 0,
    ml_rating: mlCount>0 ? Math.round((mlSum/mlCount)*10)/10 : 0,
    total_reviews: total, star_breakdown,
    recent_ratings: (ratings??[]).slice(0,20),
  };
}

export async function getDriverTripHistory(userId, page = 1, pageSize = 50) {
  const { data: bus } = await supabase
    .from('buses').select('id').eq('driver_user_id', userId).maybeSingle();
  if (!bus) return { trips: [], total: 0 };
  const offset = (page - 1) * pageSize;
  const { data, error, count } = await supabase
    .from('trips')
    .select(`
      id, status, boarded_at, alighted_at, fare_lkr,
      bus_routes ( route_number, route_name ),
      boarding_stop:boarding_stop_id ( stop_name ),
      alighting_stop:alighting_stop_id ( stop_name )
    `, { count: 'exact' })
    .eq('bus_id', bus.id).eq('status', 'completed')
    .order('alighted_at', { ascending: false })
    .range(offset, offset + pageSize - 1);
  if (error) throw error;
  return { trips: data ?? [], total: count ?? 0 };
}

export async function uploadDriverLicense(userId, fileBuffer, mimeType) {
  const ext = mimeType==='image/png'?'png':mimeType==='image/webp'?'webp':'jpg';
  const filePath = `licenses/${userId}.${ext}`;
  const { error: uploadError } = await supabase.storage
    .from('driver-licenses').upload(filePath, fileBuffer, { contentType: mimeType, upsert: true });
  if (uploadError) throw uploadError;
  const { data: signedData, error: signedError } = await supabase.storage
    .from('driver-licenses').createSignedUrl(filePath, 60*60*24*365);
  if (signedError) throw signedError;
  const { error: dbError } = await supabase.from('users')
    .update({ license_url: filePath }).eq('id', userId);
  if (dbError) throw dbError;
  return { license_url: filePath, signed_url: signedData.signedUrl };
}
