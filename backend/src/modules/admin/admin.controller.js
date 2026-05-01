import * as adminService from './admin.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';
import { getRecentEvents } from '../../services/security-audit.service.js';
import { supabase } from '../../config/supabase.js';

// ── Dashboard ──────────────────────────────────────────────────────────────────
export async function getDashboard(req, res, next) {
  try {
    const stats = await adminService.getDashboardStats();
    return sendSuccess(res, stats, 'Dashboard stats fetched');
  } catch (err) { next(err); }
}

// ── Users ──────────────────────────────────────────────────────────────────────
export async function listUsers(req, res, next) {
  try {
    const { users, pagination } = await adminService.listUsers(req.query);
    return sendSuccess(res, users, 'Users fetched', 200, pagination);
  } catch (err) { next(err); }
}

export async function getUserById(req, res, next) {
  try {
    const user = await adminService.getUserById(req.params.id);
    return sendSuccess(res, user, 'User fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function updateUser(req, res, next) {
  try {
    const user = await adminService.updateUser(req.params.id, req.body);
    await adminService.logAdminAction(req.user.id, 'UPDATE_USER', 'users', req.params.id, req.body);
    return sendSuccess(res, user, 'User updated');
  } catch (err) { next(err); }
}

export async function deactivateUser(req, res, next) {
  try {
    const user = await adminService.deactivateUser(req.params.id);
    await adminService.logAdminAction(req.user.id, 'DEACTIVATE_USER', 'users', req.params.id, {});
    return sendSuccess(res, user, 'User deactivated');
  } catch (err) { next(err); }
}

export async function reactivateUser(req, res, next) {
  try {
    const user = await adminService.reactivateUser(req.params.id);
    await adminService.logAdminAction(req.user.id, 'REACTIVATE_USER', 'users', req.params.id, {});
    return sendSuccess(res, user, 'User reactivated');
  } catch (err) { next(err); }
}

// ── Buses ──────────────────────────────────────────────────────────────────────
export async function listBuses(req, res, next) {
  try {
    const { buses, pagination } = await adminService.listAllBuses(req.query);
    return sendSuccess(res, buses, 'Buses fetched', 200, pagination);
  } catch (err) { next(err); }
}

export async function createBus(req, res, next) {
  try {
    const bus = await adminService.createBus(req.body);
    await adminService.logAdminAction(req.user.id, 'CREATE_BUS', 'buses', bus.id, req.body);
    return sendSuccess(res, bus, 'Bus created', 201);
  } catch (err) { next(err); }
}

export async function updateBus(req, res, next) {
  try {
    const bus = await adminService.updateBus(req.params.id, req.body);
    await adminService.logAdminAction(req.user.id, 'UPDATE_BUS', 'buses', req.params.id, req.body);
    return sendSuccess(res, bus, 'Bus updated');
  } catch (err) { next(err); }
}

export async function deleteBus(req, res, next) {
  try {
    await adminService.deleteBus(req.params.id);
    await adminService.logAdminAction(req.user.id, 'DELETE_BUS', 'buses', req.params.id, {});
    return sendSuccess(res, {}, 'Bus deleted');
  } catch (err) { next(err); }
}

// ── Emergency Alerts ───────────────────────────────────────────────────────────
export async function listAlerts(req, res, next) {
  try {
    const { alerts, pagination } = await adminService.listAllAlerts(req.query);
    return sendSuccess(res, alerts, 'Alerts fetched', 200, pagination);
  } catch (err) { next(err); }
}

export async function updateAlertStatus(req, res, next) {
  try {
    const alert = await adminService.adminUpdateAlertStatus(req.params.id, req.body.status, req.user.id);
    return sendSuccess(res, alert, 'Alert status updated');
  } catch (err) { next(err); }
}

// ── Fleet ──────────────────────────────────────────────────────────────────────
export async function getStandbyBuses(req, res, next) {
  try {
    const buses = await adminService.getStandbyBuses();
    return sendSuccess(res, buses, 'Standby buses fetched');
  } catch (err) { next(err); }
}

export async function deployBus(req, res, next) {
  try {
    const bus = await adminService.deployStandbyBus(req.params.id, req.body.route_id, req.user.id);
    return sendSuccess(res, bus, 'Bus deployed');
  } catch (err) { next(err); }
}

export async function recallBus(req, res, next) {
  try {
    const bus = await adminService.recallBus(req.params.id, req.user.id);
    return sendSuccess(res, bus, 'Bus recalled to standby');
  } catch (err) { next(err); }
}

// ── Audit Log ──────────────────────────────────────────────────────────────────
export async function getAuditLogs(req, res, next) {
  try {
    const { logs, pagination } = await adminService.getAuditLogs(req.query);
    return sendSuccess(res, logs, 'Audit logs fetched', 200, pagination);
  } catch (err) { next(err); }
}

// ── Routes CRUD ────────────────────────────────────────────────────────────────
export async function createRoute(req, res, next) {
  try {
    const route = await adminService.createRoute(req.body);
    await adminService.logAdminAction(req.user.id, 'CREATE_ROUTE', 'bus_routes', route.id, req.body);
    return sendSuccess(res, route, 'Route created', 201);
  } catch (err) { next(err); }
}

export async function updateRoute(req, res, next) {
  try {
    const route = await adminService.updateRoute(req.params.id, req.body);
    await adminService.logAdminAction(req.user.id, 'UPDATE_ROUTE', 'bus_routes', req.params.id, req.body);
    return sendSuccess(res, route, 'Route updated');
  } catch (err) { next(err); }
}

export async function deleteRoute(req, res, next) {
  try {
    await adminService.deleteRoute(req.params.id);
    await adminService.logAdminAction(req.user.id, 'DELETE_ROUTE', 'bus_routes', req.params.id, {});
    return sendSuccess(res, {}, 'Route deleted');
  } catch (err) { next(err); }
}


// ── Driver License URL ─────────────────────────────────────────────────────────
export async function getDriverLicenseUrl(req, res, next) {
  try {
    const data = await adminService.getDriverLicenseUrl(req.params.id);
    return sendSuccess(res, data, 'License URL generated');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }

}

export async function getSecurityLogs(req, res, next) {
  try {
    const { page = 1, page_size = 20, event_type, severity } = req.query;
    const limit = Math.min(Number(page_size), 100);
    const offset = (Number(page) - 1) * limit;

    let query = supabase
      .from('security_audit_log')
      .select('*', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (event_type && event_type !== 'all') query = query.eq('event_type', event_type);
    if (severity && severity !== 'all') query = query.eq('severity', severity);

    const { data, error, count } = await query;
    if (error) throw error;

    return sendSuccess(res, {
      data: data || [],
      pagination: { page: Number(page), page_size: limit, total: count || 0 },
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteUser(req, res, next) {
  try {
    await adminService.deleteUser(req.params.id);
    await adminService.logAdminAction(req.user.id, 'DELETE_USER', 'users', req.params.id, {});
    return sendSuccess(res, {}, 'User deleted');
  } catch (err) { next(err); }
}









