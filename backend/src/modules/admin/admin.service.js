import { supabase } from '../../config/supabase.js';
import { buildPagination } from '../../utils/response.utils.js';
import { hashPassword } from '../../utils/password.utils.js';

// ── User Management ────────────────────────────────────────────────────────────

export async function listUsers(filters) {
  const { role, search, page, page_size, is_active } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('users')
    .select(
      'id, email, full_name, username, phone, membership_type, role, is_active, license_url, created_at, updated_at',
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (role)      query = query.eq('role', role);
  if (is_active !== undefined) query = query.eq('is_active', is_active);
  if (search) {
    const q = `%${search}%`;
    query = query.or(`full_name.ilike.${q},email.ilike.${q},username.ilike.${q}`);
  }

  const { data, error, count } = await query;
  if (error) throw error;

  return { users: data, pagination: buildPagination(count, page, page_size) };
}

export async function getUserById(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, username, phone, date_of_birth, avatar_url, membership_type, role, is_active, created_at, updated_at')
    .eq('id', userId)
    .single();

  if (error || !data) {
    const err = new Error('User not found'); err.statusCode = 404; err.code = 'USER_NOT_FOUND'; throw err;
  }
  return data;
}

export async function updateUser(userId, dto) {
  const { data, error } = await supabase
    .from('users')
    .update(dto)
    .eq('id', userId)
    .select('id, email, full_name, username, membership_type, role, is_active, updated_at')
    .single();

  if (error) throw error;
  return data;
}

export async function deactivateUser(userId) {
  const { data, error } = await supabase
    .from('users')
    .update({ is_active: false })
    .eq('id', userId)
    .select('id, email, is_active')
    .single();

  if (error) throw error;
  return data;
}

export async function reactivateUser(userId) {
  const { data, error } = await supabase
    .from('users')
    .update({ is_active: true })
    .eq('id', userId)
    .select('id, email, is_active')
    .single();

  if (error) throw error;
  return data;
}

// ── Bus Management (Admin CRUD) ────────────────────────────────────────────────

export async function listAllBuses(filters) {
  const { status, route_id, page, page_size } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('buses')
    .select(
      `id, bus_number, driver_name, driver_phone, current_lat, current_lng,
       heading, speed_kmh, crowd_level, status, last_location_update, created_at,
       bus_routes ( id, route_number, route_name, origin, destination )`,
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (status)   query = query.eq('status', status);
  if (route_id) query = query.eq('route_id', route_id);

  const { data, error, count } = await query;
  if (error) throw error;

  return { buses: data, pagination: buildPagination(count, page, page_size) };
}

export async function createBus(dto) {
  const { data, error } = await supabase
    .from('buses')
    .insert(dto)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateBus(busId, dto) {
  const { data, error } = await supabase
    .from('buses')
    .update(dto)
    .eq('id', busId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteBus(busId) {
  const { error } = await supabase.from('buses').delete().eq('id', busId);
  if (error) throw error;
}

// ── Emergency Management ───────────────────────────────────────────────────────

export async function listAllAlerts(filters) {
  const { status, alert_type, page = 1, page_size = 50 } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('emergency_alerts')
    .select(
      // ← ml_priority_label was missing — added here
      `id, alert_type, description, latitude, longitude, status,
       ml_priority, ml_priority_label, ml_is_false, ml_confidence, ml_action,
       created_at, updated_at,
       users ( id, full_name, email, phone, role ),
       buses ( id, bus_number, driver_name )`,
      { count: 'exact' }
    )
    // ← Sort: highest ML priority first (P5 CRITICAL → P1 FALSE),
    //   then newest within same priority
    .order('ml_priority', { ascending: false, nullsFirst: false })
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (status)     query = query.eq('status', status);
  if (alert_type) query = query.eq('alert_type', alert_type);

  const { data, error, count } = await query;
  if (error) throw error;

  return { alerts: data, pagination: buildPagination(count, page, page_size) };
}

export async function adminUpdateAlertStatus(alertId, status, adminId) {
  const { data, error } = await supabase
    .from('emergency_alerts')
    .update({ status, updated_at: new Date().toISOString() })
    .eq('id', alertId)
    .select()
    .single();

  if (error) throw error;

  await logAdminAction(adminId, 'UPDATE_ALERT_STATUS', 'emergency_alerts', alertId, { status });

  return data;
}

// ── Fleet / Standby Bus Management ────────────────────────────────────────────

export async function getStandbyBuses() {
  const { data, error } = await supabase
    .from('buses')
    .select(`id, bus_number, driver_name, driver_phone, status,
             bus_routes ( route_number, route_name )`)
    .eq('status', 'inactive')
    .order('bus_number');

  if (error) throw error;
  return data;
}

export async function deployStandbyBus(busId, routeId, adminId) {
  const { data, error } = await supabase
    .from('buses')
    .update({ status: 'active', route_id: routeId })
    .eq('id', busId)
    .select()
    .single();

  if (error) throw error;

  await logAdminAction(adminId, 'DEPLOY_STANDBY_BUS', 'buses', busId, { route_id: routeId });
  return data;
}

export async function recallBus(busId, adminId) {
  const { data, error } = await supabase
    .from('buses')
    .update({ status: 'inactive' })
    .eq('id', busId)
    .select()
    .single();

  if (error) throw error;
  await logAdminAction(adminId, 'RECALL_BUS', 'buses', busId, {});
  return data;
}

// ── Dashboard Stats ────────────────────────────────────────────────────────────

export async function getDashboardStats() {
  const [
    { count: totalUsers },
    { count: activePassengers },
    { count: totalBuses },
    { count: activeBuses },
    { count: pendingAlerts },
    { count: criticalAlerts },
    { count: ongoingTrips },
    { count: todayTrips },
  ] = await Promise.all([
    supabase.from('users').select('id', { count: 'exact', head: true }),
    supabase.from('users').select('id', { count: 'exact', head: true }).eq('role', 'passenger').eq('is_active', true),
    supabase.from('buses').select('id', { count: 'exact', head: true }),
    supabase.from('buses').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    supabase.from('emergency_alerts').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('emergency_alerts').select('id', { count: 'exact', head: true }).eq('status', 'pending').gte('ml_priority', 4),
    supabase.from('trips').select('id', { count: 'exact', head: true }).eq('status', 'ongoing'),
    supabase.from('trips').select('id', { count: 'exact', head: true }).gte('boarded_at', new Date(new Date().setHours(0,0,0,0)).toISOString()),
  ]);

  return {
    users:  { total: totalUsers, active_passengers: activePassengers },
    buses:  { total: totalBuses, active: activeBuses, inactive: totalBuses - activeBuses },
    alerts: { pending: pendingAlerts, critical_pending: criticalAlerts },
    trips:  { ongoing: ongoingTrips, today: todayTrips },
  };
}

// ── Audit Log ─────────────────────────────────────────────────────────────────

// AFTER — proper try/catch works correctly
export async function logAdminAction(adminId, action, table, recordId, metadata = {}) {
  try {
    await supabase.from('admin_audit_logs').insert({
      admin_id:   adminId,
      action,
      table_name: table,
      record_id:  recordId,
      metadata,
    });
  } catch (e) {
    console.warn('Audit log insert failed:', e.message);
  }
}

export async function getAuditLogs(filters) {
  const { admin_id, action, page, page_size } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('admin_audit_logs')
    .select(
      `id, action, table_name, record_id, metadata, created_at,
       users ( id, full_name, email )`,
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (admin_id) query = query.eq('admin_id', admin_id);
  if (action)   query = query.eq('action', action);

  const { data, error, count } = await query;
  if (error) throw error;

  return { logs: data, pagination: buildPagination(count, page, page_size) };
}

// ── Route Management ──────────────────────────────────────────────────────────

export async function createRoute(dto) {
  const { data, error } = await supabase
    .from('bus_routes')
    .insert(dto)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function updateRoute(routeId, dto) {
  const { data, error } = await supabase
    .from('bus_routes')
    .update(dto)
    .eq('id', routeId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function deleteRoute(routeId) {
  const { error } = await supabase.from('bus_routes').delete().eq('id', routeId);
  if (error) throw error;
}


export async function getDriverLicenseUrl(userId) {
  const { data: user } = await supabase
    .from('users')
    .select('license_url')
    .eq('id', userId)
    .maybeSingle();

  if (!user?.license_url) {
    const err = new Error('No license found'); err.statusCode = 404; throw err;
  }

  const { data, error } = await supabase.storage
    .from('driver-licenses')
    .createSignedUrl(user.license_url, 60 * 60); // 1 hour

  if (error) throw error;
  return { signed_url: data.signedUrl };
}

export async function deleteUser(userId) {
  // Delete related records first
  await supabase.from('refresh_tokens').delete().eq('user_id', userId);
  await supabase.from('notification_preferences').delete().eq('user_id', userId);
  
  const { error } = await supabase.from('users').delete().eq('id', userId);
  if (error) throw error;
}






