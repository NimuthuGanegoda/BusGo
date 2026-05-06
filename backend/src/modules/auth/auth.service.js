import crypto from 'crypto';
import dns from 'dns';
dns.setDefaultResultOrder('ipv4first');
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
import { sendPasswordResetPin } from '../../utils/email.utils.js';
import { logSecurityEvent, SECURITY_EVENTS } from '../../services/security-audit.service.js';

const MAX_FAILED_ATTEMPTS  = 5;
const LOCKOUT_DURATION_MS  = 15 * 60 * 1000;

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export async function registerUser(dto, req = null) {
  const email = dto.email.toLowerCase().trim();

  const { data: existing } = await supabase
    .from('users').select('id').eq('email', email).maybeSingle();
  if (existing) {
    const err = new Error('Email already registered');
    err.statusCode = 409; err.code = 'EMAIL_TAKEN'; throw err;
  }

  if (dto.username) {
    const { data: existingUsername } = await supabase
      .from('users').select('id').eq('username', dto.username).maybeSingle();
    if (existingUsername) {
      const err = new Error('Username already taken');
      err.statusCode = 409; err.code = 'USERNAME_TAKEN'; throw err;
    }
  }

  validatePasswordStrength(dto.password);
  const password_hash = await hashPassword(dto.password);
  const role          = dto.role === 'driver' ? 'driver' : 'passenger';
  const is_active     = role === 'driver' ? false : true;

  const { data: user, error } = await supabase
    .from('users')
    .insert({
      email,
      password_hash,
      full_name:        dto.full_name,
      username:         dto.username       || null,
      phone:            dto.phone          || null,
      date_of_birth:    dto.date_of_birth  || null,
      experience_areas: dto.experience_areas || [],
      role,
      is_active,
      reset_pin:            null,
      reset_pin_expires_at: null,
    })
    .select('id, email, full_name, username, phone, avatar_url, membership_type, role, is_active, qr_token, created_at')
    .single();

  if (error) throw error;

  await supabase.from('notification_preferences').insert({ user_id: user.id });

  await logSecurityEvent({
    eventType: SECURITY_EVENTS.REGISTRATION,
    userId:    user.id,
    email,
    req,
    details:   { role, is_active },
    severity:  'info',
  });

  if (role === 'driver') {
    return {
      pending_verification: false,
      pending_approval:     true,
      email,
      message: 'Registration submitted. Please wait for admin approval.',
    };
  }

  const { access_token, refresh_token } = await issueTokenPair(user.id, user.email);
  return {
    pending_verification: false,
    email,
    user,
    access_token,
    refresh_token,
    message: 'Registration successful.',
  };
}

export async function verifyEmailPin(email, pin) {
  const { data: user, error } = await supabase
    .from('users')
    .select('id, email, full_name, username, phone, avatar_url, membership_type, role, is_active, reset_pin, reset_pin_expires_at, qr_token, created_at')
    .eq('email', email.toLowerCase().trim())
    .maybeSingle();

  if (error || !user) {
    const err = new Error('Invalid or expired PIN');
    err.statusCode = 400; err.code = 'INVALID_PIN'; throw err;
  }

  if (!user.reset_pin) {
    const err = new Error('No verification PIN found. Please register again or request a new PIN.');
    err.statusCode = 400; err.code = 'INVALID_PIN'; throw err;
  }

  if (new Date(user.reset_pin_expires_at) < new Date()) {
    const err = new Error('PIN has expired. Please request a new one.');
    err.statusCode = 400; err.code = 'PIN_EXPIRED'; throw err;
  }

  const valid = await verifyPin(pin, user.reset_pin);
  if (!valid) {
    const err = new Error('Incorrect PIN. Please try again.');
    err.statusCode = 400; err.code = 'INVALID_PIN'; throw err;
  }

  await supabase
    .from('users')
    .update({ reset_pin: null, reset_pin_expires_at: null })
    .eq('id', user.id);

  const { access_token, refresh_token } = await issueTokenPair(user.id, user.email);

  const { reset_pin: _, reset_pin_expires_at: __, ...safeUser } = user;
  return { user: safeUser, access_token, refresh_token };
}

export async function resendVerificationPin(email) {
  const { data: user } = await supabase
    .from('users')
    .select('id, full_name, reset_pin')
    .eq('email', email.toLowerCase().trim())
    .maybeSingle();

  if (!user) return;

  const pin       = generatePin();
  const pinHash   = await hashPin(pin);
  const expiresAt = new Date(Date.now() + CONSTANTS.RESET_PIN_EXPIRES_MS).toISOString();

  await supabase
    .from('users')
    .update({ reset_pin: pinHash, reset_pin_expires_at: expiresAt })
    .eq('id', user.id);

  console.log(`\n==============================`);
  console.log(`  BusGo Verification PIN (resend)`);
  console.log(`  Email : ${email}`);
  console.log(`  PIN   : ${pin}`);
  console.log(`==============================\n`);
}

export async function loginUser(dto, req = null) {
  const email = dto.email.toLowerCase().trim();

  const { data: user, error } = await supabase
    .from('users')
    .select('id, email, password_hash, full_name, username, phone, avatar_url, membership_type, role, is_active, failed_login_attempts, locked_until, reset_pin')
    .eq('email', email)
    .maybeSingle();

  if (error || !user) {
    await logSecurityEvent({
      eventType: SECURITY_EVENTS.LOGIN_FAILED,
      email, req,
      details: { reason: 'USER_NOT_FOUND' },
      severity: 'warning',
    });
    const err = new Error('Invalid email or password');
    err.statusCode = 401; err.code = 'INVALID_CREDENTIALS'; throw err;
  }

  if (user.reset_pin) {
    const err = new Error('Please verify your email first. Check your inbox for the PIN.');
    err.statusCode = 403; err.code = 'EMAIL_NOT_VERIFIED'; throw err;
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    const minutesLeft = Math.ceil((new Date(user.locked_until) - new Date()) / 60000);
    await logSecurityEvent({
      eventType: SECURITY_EVENTS.LOGIN_FAILED,
      userId: user.id, email, req,
      details: { reason: 'ACCOUNT_LOCKED', minutes_remaining: minutesLeft },
      severity: 'warning',
    });
    const err = new Error(`Account temporarily locked. Try again in ${minutesLeft} minute${minutesLeft === 1 ? '' : 's'}.`);
    err.statusCode = 423; err.code = 'ACCOUNT_LOCKED'; throw err;
  }

  if (user.locked_until && new Date(user.locked_until) <= new Date()) {
    await supabase.from('users')
      .update({ failed_login_attempts: 0, locked_until: null }).eq('id', user.id);
    user.failed_login_attempts = 0;
    user.locked_until          = null;
  }

  if (!user.is_active) {
    await logSecurityEvent({
      eventType: SECURITY_EVENTS.LOGIN_FAILED,
      userId: user.id, email, req,
      details: { reason: user.role === 'driver' ? 'PENDING_APPROVAL' : 'ACCOUNT_INACTIVE' },
      severity: 'info',
    });
    const err = new Error(
      user.role === 'driver'
        ? 'Your driver account is pending admin approval. Please wait.'
        : 'Account is deactivated. Contact support.'
    );
    err.statusCode = 403;
    err.code       = user.role === 'driver' ? 'PENDING_APPROVAL' : 'ACCOUNT_INACTIVE';
    throw err;
  }

  const valid = await comparePassword(dto.password, user.password_hash);
  if (!valid) {
    const attempts    = (user.failed_login_attempts || 0) + 1;
    const updateData  = { failed_login_attempts: attempts, last_failed_login: new Date().toISOString() };
    if (attempts >= MAX_FAILED_ATTEMPTS) {
      updateData.locked_until = new Date(Date.now() + LOCKOUT_DURATION_MS).toISOString();
      await logSecurityEvent({
        eventType: SECURITY_EVENTS.ACCOUNT_LOCKED,
        userId: user.id, email, req,
        details: { attempts, lockout_minutes: LOCKOUT_DURATION_MS / 60000 },
        severity: 'critical',
      });
    }
    await supabase.from('users').update(updateData).eq('id', user.id);
    await logSecurityEvent({
      eventType: SECURITY_EVENTS.LOGIN_FAILED,
      userId: user.id, email, req,
      details: { reason: 'WRONG_PASSWORD', attempts, max_attempts: MAX_FAILED_ATTEMPTS, locked: attempts >= MAX_FAILED_ATTEMPTS },
      severity: attempts >= MAX_FAILED_ATTEMPTS - 1 ? 'warning' : 'info',
    });
    const err = new Error('Invalid email or password');
    err.statusCode = 401; err.code = 'INVALID_CREDENTIALS'; throw err;
  }

  const ipAddress = req
    ? req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() || req.ip
    : null;

  await supabase.from('users').update({
    failed_login_attempts:  0,
    locked_until:           null,
    last_successful_login:  new Date().toISOString(),
    last_login_ip:          ipAddress,
  }).eq('id', user.id);

  const { access_token, refresh_token } = await issueTokenPair(user.id, user.email);
  const { password_hash: _, failed_login_attempts: __, locked_until: ___, reset_pin: ____, ...safeUser } = user;

  await logSecurityEvent({
    eventType: SECURITY_EVENTS.LOGIN_SUCCESS,
    userId: user.id, email, req,
    details: { role: user.role },
    severity: 'info',
  });

  return { user: safeUser, access_token, refresh_token };
}

export async function logoutUser(refreshToken, req = null, userId = null) {
  const tokenHash = hashToken(refreshToken);
  await supabase.from('refresh_tokens').update({ revoked: true }).eq('token_hash', tokenHash);
  await logSecurityEvent({ eventType: SECURITY_EVENTS.LOGOUT, userId, req, severity: 'info' });
}

export async function refreshTokens(refreshToken) {
  let decoded;
  try { decoded = verifyRefreshToken(refreshToken); }
  catch {
    const err = new Error('Invalid or expired refresh token');
    err.statusCode = 401; err.code = 'INVALID_REFRESH_TOKEN'; throw err;
  }
  const tokenHash = hashToken(refreshToken);
  const { data: storedToken } = await supabase
    .from('refresh_tokens').select('id, revoked, expires_at')
    .eq('token_hash', tokenHash).maybeSingle();
  if (!storedToken || storedToken.revoked || new Date(storedToken.expires_at) < new Date()) {
    const err = new Error('Refresh token revoked or expired');
    err.statusCode = 401; err.code = 'REFRESH_TOKEN_INVALID'; throw err;
  }
  await supabase.from('refresh_tokens').update({ revoked: true }).eq('id', storedToken.id);
  const { data: user } = await supabase.from('users').select('email').eq('id', decoded.id).single();
  return issueTokenPair(decoded.id, user.email);
}

export async function requestPasswordReset(email, req = null) {
  const emailLower = email.toLowerCase().trim();
  const { data: user } = await supabase
    .from('users').select('id, full_name').eq('email', emailLower).maybeSingle();
  if (!user) return;
  const pin       = generatePin();
  const pinHash   = await hashPin(pin);
  const expiresAt = new Date(Date.now() + CONSTANTS.RESET_PIN_EXPIRES_MS).toISOString();
  await supabase.from('users')
    .update({ reset_pin: pinHash, reset_pin_expires_at: expiresAt }).eq('id', user.id);
  await logSecurityEvent({
    eventType: SECURITY_EVENTS.PASSWORD_RESET,
    userId: user.id, email: emailLower, req,
    details: { stage: 'PIN_REQUESTED' }, severity: 'info',
  });
  try {
    await sendPasswordResetPin(emailLower, pin, user.full_name);
    logger.info(`Password reset PIN sent to ${emailLower}`);
  } catch (emailErr) {
    logger.error(`Failed to send reset email to ${emailLower}: ${emailErr.message}`);
    console.log(`\n==============================`);
    console.log(`  BusGo Password Reset PIN`);
    console.log(`  Email : ${emailLower}`);
    console.log(`  PIN   : ${pin}`);
    console.log(`==============================\n`);
  }
}

export async function verifyResetPin(email, pin) {
  const { data: user } = await supabase
    .from('users').select('id, reset_pin, reset_pin_expires_at')
    .eq('email', email.toLowerCase().trim()).maybeSingle();
  if (!user || !user.reset_pin) {
    const err = new Error('Invalid or expired PIN');
    err.statusCode = 400; err.code = 'INVALID_PIN'; throw err;
  }
  if (new Date(user.reset_pin_expires_at) < new Date()) {
    const err = new Error('PIN has expired. Please request a new one.');
    err.statusCode = 400; err.code = 'PIN_EXPIRED'; throw err;
  }
  const valid = await verifyPin(pin, user.reset_pin);
  if (!valid) {
    const err = new Error('Invalid or expired PIN');
    err.statusCode = 400; err.code = 'INVALID_PIN'; throw err;
  }
  const reset_token = signResetToken({ id: user.id, email });
  return { reset_token };
}

export async function resetPassword(dto, req = null) {
  let decoded;
  try { decoded = verifyResetToken(dto.reset_token); }
  catch {
    const err = new Error('Invalid or expired reset token');
    err.statusCode = 400; err.code = 'INVALID_RESET_TOKEN'; throw err;
  }
  validatePasswordStrength(dto.new_password);
  const password_hash = await hashPassword(dto.new_password);
  const { error } = await supabase.from('users').update({
    password_hash,
    reset_pin:             null,
    reset_pin_expires_at:  null,
    failed_login_attempts: 0,
    locked_until:          null,
  }).eq('id', decoded.id);
  if (error) throw error;
  await supabase.from('refresh_tokens')
    .update({ revoked: true }).eq('user_id', decoded.id).eq('revoked', false);
  await logSecurityEvent({
    eventType: SECURITY_EVENTS.PASSWORD_CHANGE,
    userId: decoded.id, email: decoded.email, req,
    details: { stage: 'PASSWORD_RESET_COMPLETE' }, severity: 'info',
  });
}

function validatePasswordStrength(password) {
  if (!password || password.length < 8) {
    const err = new Error('Password must be at least 8 characters');
    err.statusCode = 400; err.code = 'WEAK_PASSWORD'; throw err;
  }
  if (!/[A-Z]/.test(password)) {
    const err = new Error('Password must contain at least one uppercase letter');
    err.statusCode = 400; err.code = 'WEAK_PASSWORD'; throw err;
  }
  if (!/[a-z]/.test(password)) {
    const err = new Error('Password must contain at least one lowercase letter');
    err.statusCode = 400; err.code = 'WEAK_PASSWORD'; throw err;
  }
  if (!/[0-9]/.test(password)) {
    const err = new Error('Password must contain at least one number');
    err.statusCode = 400; err.code = 'WEAK_PASSWORD'; throw err;
  }
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    const err = new Error('Password must contain at least one special character');
    err.statusCode = 400; err.code = 'WEAK_PASSWORD'; throw err;
  }
}

async function issueTokenPair(userId, email) {
  const access_token  = signAccessToken({ id: userId, email });
  const refresh_token = signRefreshToken({ id: userId });
  const tokenHash     = hashToken(refresh_token);
  const expiresAt     = new Date(Date.now() + env.JWT_REFRESH_EXPIRES_IN * 1000).toISOString();
  await supabase.from('refresh_tokens').insert({
    user_id: userId, token_hash: tokenHash, expires_at: expiresAt,
  });
  return { access_token, refresh_token };
}