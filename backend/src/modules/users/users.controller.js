import * as usersService from './users.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';
import { CONSTANTS } from '../../config/constants.js';

export async function getMe(req, res, next) {
  try {
    const user = await usersService.getMyProfile(req.user.id);
    return sendSuccess(res, user, 'Profile fetched');
  } catch (err) {
    next(err);
  }
}

export async function updateMe(req, res, next) {
  try {
    const user = await usersService.updateMyProfile(req.user.id, req.body);
    return sendSuccess(res, user, 'Profile updated');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function uploadAvatar(req, res, next) {
  try {
    if (!req.file) {
      return sendError(res, 'No file uploaded', 400, 'NO_FILE');
    }
    const { mimetype, buffer, size } = req.file;

    if (!CONSTANTS.AVATAR_ALLOWED_MIME_TYPES.includes(mimetype)) {
      return sendError(res, 'Only JPEG, PNG and WebP images are allowed', 415, 'INVALID_FILE_TYPE');
    }
    if (size > CONSTANTS.AVATAR_MAX_SIZE_BYTES) {
      return sendError(res, 'File exceeds 5 MB limit', 413, 'FILE_TOO_LARGE');
    }

    const result = await usersService.uploadAvatar(req.user.id, buffer, mimetype);
    return sendSuccess(res, result, 'Avatar uploaded');
  } catch (err) {
    next(err);
  }
}

export async function getMyPreferences(req, res, next) {
  try {
    const prefs = await usersService.getMyPreferences(req.user.id);
    return sendSuccess(res, prefs, 'Preferences fetched');
  } catch (err) {
    next(err);
  }
}

export async function updateMyPreferences(req, res, next) {
  try {
    const prefs = await usersService.updateMyPreferences(req.user.id, req.body);
    return sendSuccess(res, prefs, 'Preferences updated');
  } catch (err) {
    next(err);
  }
}

export async function getMyStats(req, res, next) {
  try {
    const stats = await usersService.getMyStats(req.user.id);
    return sendSuccess(res, stats, 'Stats fetched');
  } catch (err) {
    next(err);
  }
}
