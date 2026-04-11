import { supabase } from '../../config/supabase.js';
import { prioritizeAlert } from '../../utils/ml.client.js';

export async function getMyAlerts(userId) {
  const { data, error } = await supabase
    .from('emergency_alerts')
    .select('id, alert_type, description, latitude, longitude, status, ml_priority, ml_priority_label, ml_is_false, ml_action, created_at, updated_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

export async function createAlert(userId, dto) {
  // 1. Insert alert first to get the ID
  const { data, error } = await supabase
    .from('emergency_alerts')
    .insert({
      user_id:     userId,
      alert_type:  dto.alert_type,
      description: dto.description || null,
      bus_id:      dto.bus_id || null,
      trip_id:     dto.trip_id || null,
      latitude:    dto.latitude || null,
      longitude:   dto.longitude || null,
      status:      'pending',
    })
    .select()
    .single();

  if (error) throw error;

  // 2. Run ML prioritization in parallel (non-blocking on failure)
  const mlResult = await prioritizeAlert({
    alert_id:       data.id,
    bus_id:         dto.bus_id || 'unknown',
    emergency_type: dto.alert_type,
    comment:        dto.description || '',
  });

  // 3. Store ML result back to alert record
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

    // Merge ML result into return object
    Object.assign(data, {
      ml_priority:       mlResult.priority,
      ml_priority_label: mlResult.priority_label,
      ml_is_false:       mlResult.is_false_alert,
      ml_action:         mlResult.action,
    });
  }

  // 4. Notify user that alert was received
  await supabase.from('notifications').insert({
    user_id:  userId,
    category: 'emergency',
    title:    '⚠️ Emergency Alert Sent',
    body:     `Your ${dto.alert_type} emergency alert has been received and is being processed.`,
    meta:     { alert_id: data.id, alert_type: dto.alert_type, ml_priority: mlResult?.priority },
  });

  return data;
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
