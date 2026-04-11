import { supabase } from '../../config/supabase.js';
import { buildPagination } from '../../utils/response.utils.js';

/**
 * Return paginated notifications for the user, optionally filtered by category.
 *
 * @param {string} userId
 * @param {{ category?, unread_only, page, page_size }} filters
 * @returns {{ notifications: Array<object>, pagination: object, unread_count: number }}
 */
export async function listNotifications(userId, filters) {
  const { category, unread_only, page, page_size } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('notifications')
    .select('id, category, title, body, is_read, meta, created_at', { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (category) query = query.eq('category', category);
  if (unread_only) query = query.eq('is_read', false);

  const { data, error, count } = await query;
  if (error) throw error;

  // Total unread count (regardless of filter)
  const { count: unreadCount } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false);

  return {
    notifications: data,
    pagination: buildPagination(count, page, page_size),
    unread_count: unreadCount || 0,
  };
}

/**
 * Mark a single notification as read.
 *
 * @param {string} notificationId
 * @param {string} userId
 * @returns {object} Updated notification
 */
export async function markAsRead(notificationId, userId) {
  const { data, error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', notificationId)
    .eq('user_id', userId)
    .select()
    .maybeSingle();

  if (!data && !error) {
    const err = new Error('Notification not found');
    err.statusCode = 404;
    err.code = 'NOTIFICATION_NOT_FOUND';
    throw err;
  }
  if (error) throw error;
  return data;
}

/**
 * Mark all unread notifications as read for the user.
 *
 * @param {string} userId
 * @returns {{ updated_count: number }}
 */
export async function markAllAsRead(userId) {
  const { data, error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', userId)
    .eq('is_read', false)
    .select('id');

  if (error) throw error;
  return { updated_count: data?.length || 0 };
}

/**
 * Delete a notification (must belong to the user).
 *
 * @param {string} notificationId
 * @param {string} userId
 */
export async function deleteNotification(notificationId, userId) {
  const { data, error } = await supabase
    .from('notifications')
    .delete()
    .eq('id', notificationId)
    .eq('user_id', userId)
    .select('id')
    .maybeSingle();

  if (!data && !error) {
    const err = new Error('Notification not found');
    err.statusCode = 404;
    err.code = 'NOTIFICATION_NOT_FOUND';
    throw err;
  }
  if (error) throw error;
}
