import * as notifService from './notifications.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function listNotifications(req, res, next) {
  try {
    const { notifications, pagination, unread_count } = await notifService.listNotifications(req.user.id, req.query);
    return sendSuccess(res, { notifications, unread_count }, 'Notifications fetched', 200, pagination);
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
