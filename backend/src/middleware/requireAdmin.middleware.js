import { sendError } from '../utils/response.utils.js';
import { logSecurityEvent, SECURITY_EVENTS } from '../services/security-audit.service.js';

/**
 * Middleware: requires the authenticated user to have role === 'admin'.
 * Must be used AFTER the `authenticate` middleware.
 *
 * Usage in routes:
 *   router.get('/dashboard', authenticate, requireAdmin, controller.getDashboard);
 */
export function requireAdmin(req, res, next) {
  if (!req.user) {
    return sendError(res, 'Authentication required', 401, 'UNAUTHORIZED');
  }

  if (req.user.role !== 'admin') {
    // Log the unauthorized access attempt
    logSecurityEvent({
      eventType: SECURITY_EVENTS.ROLE_VIOLATION,
      userId: req.user.id,
      email: req.user.email,
      req,
      details: {
        attempted_route: req.originalUrl,
        method: req.method,
        user_role: req.user.role,
        required_role: 'admin',
      },
      severity: 'warning',
    });

    return sendError(res, 'Insufficient permissions', 403, 'FORBIDDEN');
  }

  next();
}

/**
 * Middleware: requires role to be one of the allowed roles.
 * More flexible than requireAdmin for routes shared between roles.
 *
 * Usage:
 *   router.get('/bus', authenticate, requireRole('driver', 'admin'), controller.getBus);
 */
export function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return sendError(res, 'Authentication required', 401, 'UNAUTHORIZED');
    }

    if (!allowedRoles.includes(req.user.role)) {
      logSecurityEvent({
        eventType: SECURITY_EVENTS.ROLE_VIOLATION,
        userId: req.user.id,
        email: req.user.email,
        req,
        details: {
          attempted_route: req.originalUrl,
          method: req.method,
          user_role: req.user.role,
          required_roles: allowedRoles,
        },
        severity: 'warning',
      });

      return sendError(res, 'Insufficient permissions', 403, 'FORBIDDEN');
    }

    next();
  };
}