import crypto from 'crypto';
import { supabase } from '../../config/supabase.js';
import { CONSTANTS } from '../../config/constants.js';
import { env } from '../../config/env.js';
import { hashPassword, comparePassword } from '../../utils/password.utils.js';
import { hashPin, verifyPin, generatePin } from '../../utils/pin.utils.js';
import {
  signAccessToken,
  signRefreshToken,
  signResetToken,
  verifyRefreshToken,
  verifyResetToken,
} from '../../utils/jwt.utils.js';
import { logger } from '../../utils/logger.js';

/**
 * Hash a refresh token string for safe DB storage.
 *
 * @param {string} token
 * @returns {string} SHA-256 hex digest
 */
function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/**
 * Register a new user, create notification preferences, and return tokens.
 *
 * @param {{ email, password, full_name, username?, phone?, date_of_birth?, membership_type }} dto
 * @returns {{ user, access_token, refresh_token }}
 */
export async function registerUser(dto) {
  // Check email uniqueness
  const { data: existing } = await supabase
    .from('users')
    .select('id')
    .eq('email', dto.email)
    .maybeSingle();

  if (existing) {
    const err = new Error('Email already registered');
    err.statusCode = 409;
    err.code = 'EMAIL_TAKEN';
    throw err;
  }

  // Check username uniqueness if provided
  if (dto.username) {
    const { data: existingUsername } = await supabase
      .from('users')
      .select('id')
      .eq('username', dto.username)
      .maybeSingle();

    if (existingUsername) {
      const err = new Error('Username already taken');
      err.statusCode = 409;
      err.code = 'USERNAME_TAKEN';
      throw err;
    }
  }

  const password_hash = await hashPassword(dto.password);

  const { data: user, error } = await supabase
    .from('users')
    .insert({
      email: dto.email,
      password_hash,
      full_name: dto.full_name,
      username: dto.username || null,
      phone: dto.phone || null,
      date_of_birth: dto.date_of_birth || null,
      membership_type: dto.membership_type,
    })
    .select('id, email, full_name, username, phone, avatar_url, membership_type, qr_token, created_at')
    .single();

  if (error) throw error;

  // Create default notification preferences
  await supabase.from('notification_preferences').insert({ user_id: user.id });

  const { access_token, refresh_token } = await issueTokenPair(user.id, user.email);

  return { user, access_token, refresh_token };
}

/**
 * Authenticate a user with email & password.
 *
 * @param {{ email, password }} dto
 * @returns {{ user, access_token, refresh_token }}
 */
export async function loginUser(dto) {
  const { data: user, error } = await supabase
    .from('users')
    .select('id, email, password_hash, full_name, username, phone, avatar_url, membership_type, role, is_active')
    .eq('email', dto.email)
    .maybeSingle();

  if (error || !user) {
    const err = new Error('Invalid email or password');
    err.statusCode = 401;
    err.code = 'INVALID_CREDENTIALS';
    throw err;
  }

  if (!user.is_active) {
    const err = new Error('Account is deactivated');
    err.statusCode = 403;
    err.code = 'ACCOUNT_INACTIVE';
    throw err;
  }

  const valid = await comparePassword(dto.password, user.password_hash);
  if (!valid) {
    const err = new Error('Invalid email or password');
    err.statusCode = 401;
    err.code = 'INVALID_CREDENTIALS';
    throw err;
  }

  const { access_token, refresh_token } = await issueTokenPair(user.id, user.email);

  const { password_hash: _, ...safeUser } = user;
  return { user: safeUser, access_token, refresh_token };
}

/**
 * Revoke a refresh token (logout).
 *
 * @param {string} refreshToken
 */
export async function logoutUser(refreshToken) {
  const tokenHash = hashToken(refreshToken);
  await supabase
    .from('refresh_tokens')
    .update({ revoked: true })
    .eq('token_hash', tokenHash);
}

/**
 * Rotate refresh token — verify old one, issue a new pair.
 *
 * @param {string} refreshToken
 * @returns {{ access_token, refresh_token }}
 */
export async function refreshTokens(refreshToken) {
  let decoded;
  try {
    decoded = verifyRefreshToken(refreshToken);
  } catch {
    const err = new Error('Invalid or expired refresh token');
    err.statusCode = 401;
    err.code = 'INVALID_REFRESH_TOKEN';
    throw err;
  }

  const tokenHash = hashToken(refreshToken);
  const { data: storedToken } = await supabase
    .from('refresh_tokens')
    .select('id, revoked, expires_at')
    .eq('token_hash', tokenHash)
    .maybeSingle();

  if (!storedToken || storedToken.revoked || new Date(storedToken.expires_at) < new Date()) {
    const err = new Error('Refresh token revoked or expired');
    err.statusCode = 401;
    err.code = 'REFRESH_TOKEN_INVALID';
    throw err;
  }

  // Revoke old token (rotation)
  await supabase.from('refresh_tokens').update({ revoked: true }).eq('id', storedToken.id);

  const { data: user } = await supabase
    .from('users')
    .select('email')
    .eq('id', decoded.id)
    .single();

  return issueTokenPair(decoded.id, user.email);
}

/**
 * Step 1 — Generate a 6-digit reset PIN and store its hash.
 * Logs the PIN to console (no email service required).
 *
 * @param {string} email
 */
export async function requestPasswordReset(email) {
  const { data: user } = await supabase
    .from('users')
    .select('id, full_name')
    .eq('email', email)
    .maybeSingle();

  // Always respond success to prevent user enumeration
  if (!user) return;

  const pin = generatePin();
  const pinHash = await hashPin(pin);
  const expiresAt = new Date(Date.now() + CONSTANTS.RESET_PIN_EXPIRES_MS).toISOString();

  await supabase
    .from('users')
    .update({ reset_pin: pinHash, reset_pin_expires_at: expiresAt })
    .eq('id', user.id);

  // Log PIN (replace with email service in production)
  logger.info(`🔑 Password reset PIN for ${email}: ${pin}  (expires ${expiresAt})`);
  console.log(`\n==============================`);
  console.log(`  BusGo Password Reset PIN`);
  console.log(`  Email : ${email}`);
  console.log(`  PIN   : ${pin}`);
  console.log(`  Exp   : ${expiresAt}`);
  console.log(`==============================\n`);
}

/**
 * Step 2 — Verify the PIN, return a short-lived reset_token JWT.
 *
 * @param {string} email
 * @param {string} pin
 * @returns {{ reset_token: string }}
 */
export async function verifyResetPin(email, pin) {
  const { data: user } = await supabase
    .from('users')
    .select('id, reset_pin, reset_pin_expires_at')
    .eq('email', email)
    .maybeSingle();

  if (!user || !user.reset_pin) {
    const err = new Error('Invalid or expired PIN');
    err.statusCode = 400;
    err.code = 'INVALID_PIN';
    throw err;
  }

  if (new Date(user.reset_pin_expires_at) < new Date()) {
    const err = new Error('PIN has expired. Please request a new one.');
    err.statusCode = 400;
    err.code = 'PIN_EXPIRED';
    throw err;
  }

  const valid = await verifyPin(pin, user.reset_pin);
  if (!valid) {
    const err = new Error('Invalid or expired PIN');
    err.statusCode = 400;
    err.code = 'INVALID_PIN';
    throw err;
  }

  const reset_token = signResetToken({ id: user.id, email });
  return { reset_token };
}

/**
 * Step 3 — Verify the reset_token JWT, update password, clear PIN fields.
 *
 * @param {{ reset_token, new_password, confirm_password }} dto
 */
export async function resetPassword(dto) {
  let decoded;
  try {
    decoded = verifyResetToken(dto.reset_token);
  } catch {
    const err = new Error('Invalid or expired reset token');
    err.statusCode = 400;
    err.code = 'INVALID_RESET_TOKEN';
    throw err;
  }

  const password_hash = await hashPassword(dto.new_password);

  const { error } = await supabase
    .from('users')
    .update({
      password_hash,
      reset_pin: null,
      reset_pin_expires_at: null,
    })
    .eq('id', decoded.id);

  if (error) throw error;

  // Revoke all existing refresh tokens for this user (force re-login)
  await supabase
    .from('refresh_tokens')
    .update({ revoked: true })
    .eq('user_id', decoded.id)
    .eq('revoked', false);
}

// ── Internal helpers ──────────────────────────────────────────────────────────

/**
 * Create an access + refresh token pair and persist the refresh token hash.
 *
 * @param {string} userId
 * @param {string} email
 * @returns {{ access_token: string, refresh_token: string }}
 */
async function issueTokenPair(userId, email) {
  const access_token = signAccessToken({ id: userId, email });
  const refresh_token = signRefreshToken({ id: userId });
  const tokenHash = hashToken(refresh_token);
  const expiresAt = new Date(Date.now() + env.JWT_REFRESH_EXPIRES_IN * 1000).toISOString();

  await supabase.from('refresh_tokens').insert({
    user_id: userId,
    token_hash: tokenHash,
    expires_at: expiresAt,
  });

  return { access_token, refresh_token };
}
