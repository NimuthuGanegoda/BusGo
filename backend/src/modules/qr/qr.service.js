import { v4 as uuidv4 } from 'uuid';
import { supabase } from '../../config/supabase.js';
import { CONSTANTS } from '../../config/constants.js';

export async function getMyQrCard(userId) {
  const { data: user, error } = await supabase
    .from('users')
    .select('id, full_name, username, membership_type, qr_token, qr_expires_at, created_at')
    .eq('id', userId).single();
  if (error) throw error;

  const now = new Date();
  if (new Date(user.qr_expires_at) <= now) {
    const newToken = uuidv4();
    const newExpiry = new Date(now.getTime() + CONSTANTS.QR_TOKEN_EXPIRES_MS).toISOString();
    const { data: updated, error: e } = await supabase
      .from('users').update({ qr_token: newToken, qr_expires_at: newExpiry })
      .eq('id', userId).select('qr_token, qr_expires_at').single();
    if (e) throw e;
    return { user_id: user.id, full_name: user.full_name, username: user.username,
             membership_type: user.membership_type, member_since: user.created_at,
             qr_token: updated.qr_token, qr_expires_at: updated.qr_expires_at };
  }
  return { user_id: user.id, full_name: user.full_name, username: user.username,
           membership_type: user.membership_type, member_since: user.created_at,
           qr_token: user.qr_token, qr_expires_at: user.qr_expires_at };
}

export async function scanIn(scannedToken, driverUserId, context = {}) {
  const { data: passenger, error: pErr } = await supabase
    .from('users').select('id, full_name, username, membership_type, qr_token, qr_expires_at, is_active')
    .eq('qr_token', scannedToken).maybeSingle();
  if (pErr) throw pErr;
  if (!passenger) { const e = new Error('Invalid QR code'); e.statusCode=404; e.code='INVALID_QR_TOKEN'; throw e; }
  if (!passenger.is_active) { const e = new Error('Account deactivated'); e.statusCode=403; e.code='ACCOUNT_INACTIVE'; throw e; }
  if (new Date(passenger.qr_expires_at) <= new Date()) { const e = new Error('QR expired — ask passenger to refresh'); e.statusCode=410; e.code='QR_EXPIRED'; throw e; }

  const { data: ongoing } = await supabase.from('trips').select('id').eq('user_id', passenger.id).eq('status', 'ongoing').maybeSingle();
  if (ongoing) { const e = new Error('Passenger already has an ongoing trip'); e.statusCode=409; e.code='TRIP_ALREADY_ONGOING'; throw e; }

  let busId = context.bus_id, routeId = context.route_id;
  if (!busId) {
    const { data: bus } = await supabase.from('buses').select('id, route_id').eq('driver_user_id', driverUserId).maybeSingle();
    if (bus) { busId = bus.id; routeId = routeId || bus.route_id; }
  }
  if (!busId || !routeId) { const e = new Error('Cannot determine bus or route'); e.statusCode=422; e.code='BUS_NOT_RESOLVED'; throw e; }

  const { data: trip, error: tErr } = await supabase.from('trips')
    .insert({ user_id: passenger.id, bus_id: busId, route_id: routeId, boarding_stop_id: context.boarding_stop_id||null, status: 'ongoing' })
    .select('id, boarded_at').single();
  if (tErr) throw tErr;

  // Invalidate QR immediately
  await supabase.from('users').update({ qr_expires_at: new Date(Date.now()-1).toISOString() }).eq('id', passenger.id);

  await supabase.from('notifications').insert({ user_id: passenger.id, category: 'trip',
    title: '🚌 Boarded Successfully', body: 'Your journey has started. Have a safe trip!',
    meta: { trip_id: trip.id, bus_id: busId } });

  return { trip_id: trip.id, boarded_at: trip.boarded_at,
    passenger: { id: passenger.id, full_name: passenger.full_name, username: passenger.username, membership_type: passenger.membership_type },
    message: `${passenger.full_name} boarded successfully` };
}

export async function scanExit(driverUserId, dto = {}) {
  const { scanned_token, alighting_stop_id, fare_lkr } = dto;
  const { data: passenger, error: pErr } = await supabase
    .from('users').select('id, full_name, qr_token, qr_expires_at')
    .eq('qr_token', scanned_token).maybeSingle();
  if (pErr) throw pErr;
  if (!passenger) { const e = new Error('Invalid QR code'); e.statusCode=404; e.code='INVALID_QR_TOKEN'; throw e; }
  if (new Date(passenger.qr_expires_at) <= new Date()) { const e = new Error('QR expired'); e.statusCode=410; e.code='QR_EXPIRED'; throw e; }

  const { data: trip } = await supabase.from('trips').select('id, bus_id')
    .eq('user_id', passenger.id).eq('status', 'ongoing')
    .order('boarded_at', { ascending: false }).limit(1).maybeSingle();
  if (!trip) { const e = new Error('No ongoing trip found'); e.statusCode=404; e.code='NO_ONGOING_TRIP'; throw e; }

  const now = new Date().toISOString();
  await supabase.from('trips').update({ status: 'completed', alighted_at: now, alighting_stop_id: alighting_stop_id||null, fare_lkr: fare_lkr||null }).eq('id', trip.id);
  await supabase.from('users').update({ qr_expires_at: new Date(Date.now()-1).toISOString() }).eq('id', passenger.id);
  await supabase.from('notifications').insert({ user_id: passenger.id, category: 'trip',
    title: '⭐ How was your ride?', body: 'Please rate your recent bus journey.',
    meta: { trip_id: trip.id, bus_id: trip.bus_id } });

  return { trip_id: trip.id, alighted_at: now,
    passenger: { id: passenger.id, full_name: passenger.full_name },
    message: `${passenger.full_name} alighted. Rating prompt sent.` };
}
