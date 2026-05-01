import * as authService from './auth.service.js';
import { supabase } from '../../config/supabase.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function register(req, res, next) {
  try {
    const result = await authService.registerUser(req.body, req);
    return sendSuccess(res, result, 'Registration successful. Please check your email for a verification PIN.', 201);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function login(req, res, next) {
  try {
    const result = await authService.loginUser(req.body, req);
    return sendSuccess(res, result, 'Login successful');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function logout(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (refresh_token) await authService.logoutUser(refresh_token, req, req.user?.id);
    return sendSuccess(res, {}, 'Logged out successfully');
  } catch (err) {
    next(err);
  }
}

export async function refresh(req, res, next) {
  try {
    const result = await authService.refreshTokens(req.body.refresh_token);
    return sendSuccess(res, result, 'Tokens refreshed');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

// ── Email verification (new) ──────────────────────────────────────────────────

/**
 * POST /auth/verify-email
 * Body: { email, pin }
 * Verifies the 6-digit PIN sent after registration.
 * Issues tokens on success so the user is immediately logged in.
 */
export async function verifyEmail(req, res, next) {
  try {
    const result = await authService.verifyEmailPin(req.body.email, req.body.pin);
    return sendSuccess(res, result, 'Email verified successfully');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

/**
 * POST /auth/verify-email/resend
 * Body: { email }
 * Resends a fresh verification PIN to the email.
 */
export async function resendVerificationPin(req, res, next) {
  try {
    await authService.resendVerificationPin(req.body.email);
    return sendSuccess(res, {}, 'A new verification PIN has been sent to your email');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

// ── Forgot password ───────────────────────────────────────────────────────────

export async function forgotPasswordRequest(req, res, next) {
  try {
    await authService.requestPasswordReset(req.body.email, req);
    return sendSuccess(res, {}, 'If that email exists, a reset PIN has been sent');
  } catch (err) {
    next(err);
  }
}

export async function forgotPasswordVerify(req, res, next) {
  try {
    const result = await authService.verifyResetPin(req.body.email, req.body.pin);
    return sendSuccess(res, result, 'PIN verified successfully');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function forgotPasswordReset(req, res, next) {
  try {
    await authService.resetPassword(req.body, req);
    return sendSuccess(res, {}, 'Password reset successful. Please log in with your new password.');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

// ── Public license upload ─────────────────────────────────────────────────────
export async function uploadLicense(req, res, next) {
  try {
    if (!req.file) {
      return sendError(res, 'License image is required', 400, 'NO_FILE');
    }
    if (!req.body.email) {
      return sendError(res, 'Email is required', 400, 'NO_EMAIL');
    }
    const { data: user, error: userError } = await supabase
      .from('users')
      .select('id')
      .eq('email', req.body.email.toLowerCase().trim())
      .maybeSingle();
    if (userError || !user) {
      return sendError(res, 'User not found', 404, 'USER_NOT_FOUND');
    }
    const ext = req.file.originalname?.toLowerCase().endsWith('.png') ? 'png'
              : req.file.originalname?.toLowerCase().endsWith('.webp') ? 'webp'
              : 'jpg';
    const filePath   = `licenses/${user.id}.${ext}`;
    const forcedMime = ext === 'png' ? 'image/png'
                     : ext === 'webp' ? 'image/webp'
                     : 'image/jpeg';
    const { error: uploadError } = await supabase.storage
      .from('driver-licenses')
      .upload(filePath, req.file.buffer, { contentType: forcedMime, upsert: true });
    if (uploadError) throw uploadError;
    await supabase.from('users').update({ license_url: filePath }).eq('id', user.id);
    return sendSuccess(res, { license_url: filePath }, 'License uploaded successfully');
  } catch (err) {
    next(err);
  }
}







