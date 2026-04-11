import rateLimit from 'express-rate-limit';
import { env } from '../config/env.js';
import { sendError } from '../utils/response.utils.js';

const rateLimitHandler = (req, res) => {
  return sendError(
    res,
    'Too many requests, please try again later.',
    429,
    'RATE_LIMIT_EXCEEDED'
  );
};

/**
 * Strict limiter for authentication endpoints.
 * 10 requests per 15 minutes per IP.
 */
export const authLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_AUTH_WINDOW_MS,
  max: env.RATE_LIMIT_AUTH_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
  skipSuccessfulRequests: false,
});

/**
 * General API limiter.
 * 100 requests per minute per IP.
 */
export const generalLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_GENERAL_WINDOW_MS,
  max: env.RATE_LIMIT_GENERAL_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: rateLimitHandler,
  keyGenerator: (req) => req.user?.id || req.ip, // Per-user when authenticated
});
