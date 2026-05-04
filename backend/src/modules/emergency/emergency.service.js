import { supabase } from '../../config/supabase.js';
import { prioritizeAlert } from '../../utils/ml.client.js';

export async function getMyAlerts(userId) {
  const { data, error } = await supabase
    .from('emergency_alerts')
    .select(`
      id, alert_type, description, latitude, longitude,
      status, ml_priority, ml_priority_label, ml_is_false,
      ml_action, ml_confidence, created_at, updated_at,
      bus_id, trip_id,
      buses (
        id, bus_number,
        bus_routes ( route_name, route_number )
      )
    `)
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;

  return data.map(alert => ({
    ...alert,
    bus_number:   alert.buses?.bus_number            || null,
    route_name:   alert.buses?.bus_routes?.route_name   || null,
    route_number: alert.buses?.bus_routes?.route_number || null,
  }));
}

export async function createAlert(userId, dto) {
  // ── Auto-resolve bus_id from active trip if not sent by the app ──────────
  // This is the most reliable approach — even if the Flutter app forgets to
  // send bus_id, the backend finds it from the user's current ongoing trip.
  let resolvedBusId  = dto.bus_id  || null;
  let resolvedTripId = dto.trip_id || null;

  if (!resolvedBusId) {
    const { data: activeTrip } = await supabase
      .from('trips')
      .select('id, bus_id')
      .eq('user_id', userId)
      .eq('status', 'ongoing')
      .order('boarded_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (activeTrip) {
      resolvedBusId  = activeTrip.bus_id;
      resolvedTripId = resolvedTripId || activeTrip.id;
      console.log(`[Emergency] Auto-resolved bus_id=${resolvedBusId} from active trip ${activeTrip.id}`);
    }
  }

  // ── Fetch bus number for the response ─────────────────────────────────────
  let busNumber = null;
  if (resolvedBusId) {
    const { data: busData } = await supabase
      .from('buses')
      .select('bus_number')
      .eq('id', resolvedBusId)
      .maybeSingle();
    busNumber = busData?.bus_number || null;
  }

  // ── Insert alert ──────────────────────────────────────────────────────────
  const { data, error } = await supabase
    .from('emergency_alerts')
    .insert({
      user_id:     userId,
      alert_type:  dto.alert_type,
      description: dto.description || null,
      bus_id:      resolvedBusId,
      trip_id:     resolvedTripId,
      latitude:    dto.latitude  || null,
      longitude:   dto.longitude || null,
      status:      'pending',
    })
    .select()
    .single();
  if (error) throw error;

  // ── ML prioritization ─────────────────────────────────────────────────────
  const mlResult = await prioritizeAlert({
    alert_id:       data.id,
    bus_id:         resolvedBusId || 'unknown',
    emergency_type: dto.alert_type,
    comment:        dto.description || '',
  });
  console.log('[Emergency ML] Result:', JSON.stringify(mlResult));

  if (mlResult) {
    await supabase
      .from('emergency_alerts')
      .update({
        ml_priority:       mlResult.priority,
        ml_priority_label: mlResult.priority_label,
        ml_is_false:       mlResult.is_false_alert,
        ml_confidence:     mlResult.confidence,
        ml_action:         mlResult.action,
      })
      .eq('id', data.id);

    Object.assign(data, {
      ml_priority:       mlResult.priority,
      ml_priority_label: mlResult.priority_label,
      ml_is_false:       mlResult.is_false_alert,
      ml_action:         mlResult.action,
    });
  }

  // ── Notification ──────────────────────────────────────────────────────────
  await supabase.from('notifications').insert({
    user_id:  userId,
    category: 'emergency',
    title:    '⚠️ Emergency Alert Sent',
    body:     `Your ${dto.alert_type} emergency alert has been received and is being processed.`,
    meta:     {
      alert_id:    data.id,
      alert_type:  dto.alert_type,
      ml_priority: mlResult?.priority,
    },
  });

  return { ...data, bus_number: busNumber };
}

export async function updateAlertStatus(alertId, userId, status) {
  const { data: existing } = await supabase
    .from('emergency_alerts')
    .select('id, user_id')
    .eq('id', alertId)
    .maybeSingle();

  if (!existing) {
    const err = new Error('Emergency alert not found');
    err.statusCode = 404; err.code = 'ALERT_NOT_FOUND'; throw err;
  }
  if (existing.user_id !== userId) {
    const err = new Error('Forbidden');
    err.statusCode = 403; err.code = 'FORBIDDEN'; throw err;
  }

  const { data, error } = await supabase
    .from('emergency_alerts')
    .update({ status })
    .eq('id', alertId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

