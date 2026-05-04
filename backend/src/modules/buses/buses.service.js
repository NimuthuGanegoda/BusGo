import { supabase, broadcastToChannel } from '../../config/supabase.js';
import { filterByRadius } from '../../utils/haversine.utils.js';
import { CONSTANTS } from '../../config/constants.js';

export async function getNearbyBuses(lat, lng, radius) {
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone,
      current_lat, current_lng, heading, speed_kmh,
      crowd_level, status, last_location_update,
      driver_user_id,
      bus_routes ( id, route_number, route_name, origin, destination, color ),
      users!buses_driver_user_id_fkey ( avg_rating )
    `)
    .eq('status', 'active')
    .not('current_lat', 'is', null)
    .not('current_lng', 'is', null)
    .gte('last_location_update', new Date(Date.now() - 5 * 60 * 1000).toISOString());
  if (error) throw error;
  return filterByRadius(data, lat, lng, radius, 'current_lat', 'current_lng');
}

export async function getBusById(busId) {
  const { data, error } = await supabase
    .from('buses')
    .select(`
      id, bus_number, driver_name, driver_phone,
      current_lat, current_lng, heading, speed_kmh,
      crowd_level, status, last_location_update, created_at,
      driver_user_id,
      bus_routes ( id, route_number, route_name, origin, destination, color, waypoints ),
      users!buses_driver_user_id_fkey ( avg_rating )
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


export async function recallBus(busId, adminUserId) {
  const { data: bus } = await supabase
    .from('buses').select('id, bus_number, status').eq('id', busId).maybeSingle();
  if (!bus) {
    const e = new Error('Bus not found'); e.statusCode = 404; e.code = 'BUS_NOT_FOUND'; throw e;
  }
  if (bus.status === 'recalled') {
    const e = new Error('Bus is already recalled'); e.statusCode = 409; e.code = 'ALREADY_RECALLED'; throw e;
  }

  const { data, error } = await supabase
    .from('buses')
    .update({ status: 'recalled' })
    .eq('id', busId)
    .select('id, bus_number, status')
    .single();
  if (error) throw error;

  // Audit log
  await supabase.from('admin_audit_log').insert({
    admin_user_id: adminUserId,
    action:        'RECALL_BUS',
    table_name:    'buses',
    record_id:     busId,
    metadata:      { bus_number: bus.bus_number, previous_status: bus.status },
  });

  return data;
}

export async function deployBus(busId, adminUserId) {
  const { data: bus } = await supabase
    .from('buses').select('id, bus_number, status').eq('id', busId).maybeSingle();
  if (!bus) {
    const e = new Error('Bus not found'); e.statusCode = 404; e.code = 'BUS_NOT_FOUND'; throw e;
  }

  const { data, error } = await supabase
    .from('buses')
    .update({ status: 'active', last_location_update: new Date().toISOString() })
    .eq('id', busId)
    .select('id, bus_number, status')
    .single();
  if (error) throw error;

  await supabase.from('admin_audit_log').insert({
    admin_user_id: adminUserId,
    action:        'DEPLOY_STANDBY_BUS',
    table_name:    'buses',
    record_id:     busId,
    metadata:      { bus_number: bus.bus_number, previous_status: bus.status },
  });

  return data;
}