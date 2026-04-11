import { logger } from '../utils/logger.js';
import { sendError } from '../utils/response.utils.js';
import { env } from '../config/env.js';

/**
 * Global Express error handler.
 * Must be registered LAST in app.js (4 arguments).
 *
 * @type {import('express').ErrorRequestHandler}
 */
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, next) {
  // Log full error with stack in non-production
  logger.error(err.message, {
    stack: env.NODE_ENV !== 'production' ? err.stack : undefined,
    method: req.method,
    url: req.originalUrl,
    userId: req.user?.id,
  });

  // Supabase / PostgREST errors
  if (err.code && typeof err.code === 'string' && err.code.startsWith('PGRST')) {
    return sendError(res, 'Database error', 500, 'DATABASE_ERROR');
  }

  // JWT errors that leaked through (shouldn't normally happen)
  if (err.name === 'JsonWebTokenError') {
    return sendError(res, 'Invalid token', 401, 'INVALID_TOKEN');
  }
  if (err.name === 'TokenExpiredError') {
    return sendError(res, 'Token expired', 401, 'TOKEN_EXPIRED');
  }

  // Multer file-too-large
  if (err.code === 'LIMIT_FILE_SIZE') {
    return sendError(res, 'File too large', 413, 'FILE_TOO_LARGE');
  }

  const statusCode = err.statusCode || err.status || 500;
  const message =
    env.NODE_ENV === 'production' && statusCode === 500
      ? 'Internal server error'
      : err.message || 'Internal server error';

  return sendError(res, message, statusCode, err.code || 'INTERNAL_ERROR');
}

/**
 * 404 handler — register before errorHandler, after all routes.
 *
 * @type {import('express').RequestHandler}
 */
export function notFoundHandler(req, res) {
  return sendError(res, `Route ${req.method} ${req.originalUrl} not found`, 404, 'NOT_FOUND');
}
