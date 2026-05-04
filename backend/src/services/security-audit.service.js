import { supabase } from '../config/supabase.js';
import { logger } from '../utils/logger.js';

export const SECURITY_EVENTS = {
  LOGIN_SUCCESS:              'LOGIN_SUCCESS',
  LOGIN_FAILED:               'LOGIN_FAILED',
  ACCOUNT_LOCKED:             'ACCOUNT_LOCKED',
  ACCOUNT_UNLOCKED:           'ACCOUNT_UNLOCKED',
  LOGOUT:                     'LOGOUT',
  TOKEN_REFRESH:              'TOKEN_REFRESH',
  PASSWORD_RESET:             'PASSWORD_RESET',
  PASSWORD_CHANGE:            'PASSWORD_CHANGE',
  REGISTRATION:               'REGISTRATION',
  ADMIN_ACTION:               'ADMIN_ACTION',
  ROLE_VIOLATION:             'ROLE_VIOLATION',
  RATE_LIMITED:               'RATE_LIMITED',
  CAPACITY_VIOLATION:         'CAPACITY_VIOLATION',
  DRIVER_CAPACITY_OVERRIDE:   'DRIVER_CAPACITY_OVERRIDE',
  // ── UFR_51: Repeated QR scan flagging ─────────────────────────────────────
  REPEATED_QR_SCAN:           'REPEATED_QR_SCAN',
};

export async function logSecurityEvent({
  eventType,
  userId = null,
  email = null,
  req = null,
  details = {},
  severity = 'info',
}) {
  try {
    const ipAddress = req
      ? req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip || req.socket?.remoteAddress
      : null;
    const userAgent = req?.headers['user-agent'] || null;

    await supabase.from('security_audit_log').insert({
      event_type: eventType,
      user_id:    userId,
      email,
      ip_address: ipAddress,
      user_agent: userAgent,
      details,
      severity,
    });

    const logMsg = `[SECURITY] ${eventType} | ${email || 'unknown'} | ${ipAddress || 'unknown'} | ${JSON.stringify(details)}`;
    if (severity === 'critical')     logger.error(logMsg);
    else if (severity === 'warning') logger.warn(logMsg);
    else                             logger.info(logMsg);
  } catch (err) {
    logger.error(`[AUDIT] Failed to log security event: ${err.message}`);
  }
}

export async function getRecentEvents({ limit = 50, eventType = null, severity = null } = {}) {
  let query = supabase
    .from('security_audit_log')
    .select('*, users:user_id(full_name, role)')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (eventType) query = query.eq('event_type', eventType);
  if (severity)  query = query.eq('severity', severity);
  const { data, error } = await query;
  if (error) throw error;
  return data;
}

export async function getCapacityViolations({ limit = 100 } = {}) {
  const { data, error } = await supabase
    .from('security_audit_log')
    .select('*, users:user_id(full_name, username, role)')
    .eq('event_type', SECURITY_EVENTS.CAPACITY_VIOLATION)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) throw error;
  return data;
}

export async function getFailedAttemptsFromIP(ipAddress, windowMinutes = 15) {
  const since = new Date(Date.now() - windowMinutes * 60 * 1000).toISOString();
  const { count } = await supabase
    .from('security_audit_log')
    .select('id', { count: 'exact', head: true })
    .eq('event_type', SECURITY_EVENTS.LOGIN_FAILED)
    .eq('ip_address', ipAddress)
    .gte('created_at', since);
  return count || 0;
}

