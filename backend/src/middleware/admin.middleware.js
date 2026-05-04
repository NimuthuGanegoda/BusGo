import { sendError } from '../utils/response.utils.js';

/**
 * Middleware: ensure the authenticated user has admin role.
 * Must be placed AFTER authenticate() middleware.
 *
 * Admin users have role = 'admin' in the users table.
 * They are pre-seeded in the database — self-registration is blocked.
 */
export function requireAdmin(req, res, next) {
  if (!req.user) {
    return sendError(res, 'Unauthorized', 401, 'UNAUTHORIZED');
  }
  if (!['admin', 'developer'].includes(req.user.role)) {
    return sendError(res, 'Admin access required', 403, 'FORBIDDEN');
  }
  
  next();
}







