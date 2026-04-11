import * as authService from './auth.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function register(req, res, next) {
  try {
    const result = await authService.registerUser(req.body);
    return sendSuccess(res, result, 'Registration successful', 201);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function login(req, res, next) {
  try {
    const result = await authService.loginUser(req.body);
    return sendSuccess(res, result, 'Login successful');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function logout(req, res, next) {
  try {
    const { refresh_token } = req.body;
    if (refresh_token) await authService.logoutUser(refresh_token);
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

export async function forgotPasswordRequest(req, res, next) {
  try {
    await authService.requestPasswordReset(req.body.email);
    // Always return success to prevent user enumeration
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
    await authService.resetPassword(req.body);
    return sendSuccess(res, {}, 'Password reset successful. Please log in with your new password.');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}
