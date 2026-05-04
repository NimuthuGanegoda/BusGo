import * as notifService from './notifications.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function listNotifications(req, res, next) {
  try {
    const { notifications, pagination, unread_count } =
      await notifService.listNotifications(req.user.id, req.query);
    return sendSuccess(res, { notifications, unread_count }, 'Notifications fetched', 200, pagination);
  } catch (err) {
    next(err);
  }
}

/**
 * POST /api/notifications
 * Body: { category, title, body, meta? }
 *
 * Called by the mobile app when it cannot reach Supabase directly.
 * The backend (which has internet) inserts the row on the app's behalf.
 * req.user.id comes from the JWT the app already sends on every request.
 */
export async function createNotification(req, res, next) {
  try {
    const { category, title, body, meta } = req.body;

    if (!category || !title || !body) {
      return sendError(res, 'category, title and body are required', 400, 'MISSING_FIELDS');
    }

    const notification = await notifService.createNotification(req.user.id, {
      category,
      title,
      body,
      meta: meta ?? {},
    });

    return sendSuccess(res, notification, 'Notification created', 201);
  } catch (err) {
    next(err);
  }
}

export async function markAsRead(req, res, next) {
  try {
    const notif = await notifService.markAsRead(req.params.id, req.user.id);
    return sendSuccess(res, notif, 'Notification marked as read');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function markAllAsRead(req, res, next) {
  try {
    const result = await notifService.markAllAsRead(req.user.id);
    return sendSuccess(res, result, `${result.updated_count} notification(s) marked as read`);
  } catch (err) {
    next(err);
  }
}

export async function deleteNotification(req, res, next) {
  try {
    await notifService.deleteNotification(req.params.id, req.user.id);
    return sendSuccess(res, {}, 'Notification deleted');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}








