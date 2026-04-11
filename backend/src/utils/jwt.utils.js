import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

/**
 * Sign a short-lived access token (15 min).
 *
 * @param {{ id: string, email: string }} payload
 * @returns {string} Signed JWT
 */
export function signAccessToken(payload) {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN,
    issuer: 'busgo-api',
    audience: 'busgo-client',
  });
}

/**
 * Sign a long-lived refresh token (7 days).
 *
 * @param {{ id: string }} payload
 * @returns {string} Signed JWT
 */
export function signRefreshToken(payload) {
  return jwt.sign(payload, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_EXPIRES_IN,
    issuer: 'busgo-api',
    audience: 'busgo-client',
  });
}

/**
 * Sign a short-lived password-reset token (5 min).
 *
 * @param {{ id: string, email: string }} payload
 * @returns {string} Signed JWT
 */
export function signResetToken(payload) {
  return jwt.sign(payload, env.JWT_RESET_SECRET, {
    expiresIn: env.JWT_RESET_EXPIRES_IN,
    issuer: 'busgo-api',
    audience: 'busgo-reset',
  });
}

/**
 * Verify an access token.
 *
 * @param {string} token
 * @returns {{ id: string, email: string, iat: number, exp: number }}
 * @throws {JsonWebTokenError | TokenExpiredError}
 */
export function verifyAccessToken(token) {
  return jwt.verify(token, env.JWT_ACCESS_SECRET, {
    issuer: 'busgo-api',
    audience: 'busgo-client',
  });
}

/**
 * Verify a refresh token.
 *
 * @param {string} token
 * @returns {{ id: string, iat: number, exp: number }}
 * @throws {JsonWebTokenError | TokenExpiredError}
 */
export function verifyRefreshToken(token) {
  return jwt.verify(token, env.JWT_REFRESH_SECRET, {
    issuer: 'busgo-api',
    audience: 'busgo-client',
  });
}

/**
 * Verify a password-reset token.
 *
 * @param {string} token
 * @returns {{ id: string, email: string, iat: number, exp: number }}
 * @throws {JsonWebTokenError | TokenExpiredError}
 */
export function verifyResetToken(token) {
  return jwt.verify(token, env.JWT_RESET_SECRET, {
    issuer: 'busgo-api',
    audience: 'busgo-reset',
  });
}
