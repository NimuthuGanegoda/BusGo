import { supabase } from '../../config/supabase.js';
import { buildPagination } from '../../utils/response.utils.js';

/**
 * Return paginated notifications for the user, optionally filtered by category.
 */
export async function listNotifications(userId, filters) {
  const { category, unread_only, page = 1, page_size = 20 } = filters;
  const offset = (page - 1) * page_size;

  let query = supabase
    .from('notifications')
    .select('id, category, title, body, is_read, meta, created_at', { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + page_size - 1);

  if (category)    query = query.eq('category', category);
  if (unread_only) query = query.eq('is_read', false);

  const { data, error, count } = await query;
  if (error) throw error;

  const { count: unreadCount } = await supabase
    .from('notifications')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('is_read', false);

  return {
    notifications: data,
    pagination:    buildPagination(count, page, page_size),
    unread_count:  unreadCount || 0,
  };
}

/**
 * Create a notification row for a user.
 * Called by the backend itself (e.g. from bus arrival logic)
 * OR via POST /api/notifications from the mobile app.
 *
 * @param {string} userId
 * @param {{ category: string, title: string, body: string, meta?: object }} payload
 * @returns {object} Inserted notification row
 */
export async function createNotification(userId, { category, title, body, meta = {} }) {
  const { data, error } = await supabase
    .from('notifications')
    .insert({
      user_id:  userId,
      category,
      title,
      body,
      is_read:  false,
      meta,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Mark a single notification as read.
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



