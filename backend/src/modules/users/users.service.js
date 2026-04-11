import { supabase } from '../../config/supabase.js';
import { env } from '../../config/env.js';
import { CONSTANTS } from '../../config/constants.js';

/**
 * Fetch the full profile of the authenticated user.
 *
 * @param {string} userId
 * @returns {object} User record (no password_hash)
 */
export async function getMyProfile(userId) {
  const { data, error } = await supabase
    .from('users')
    .select('id, email, full_name, username, phone, date_of_birth, avatar_url, membership_type, qr_token, qr_expires_at, is_active, created_at, updated_at')
    .eq('id', userId)
    .single();

  if (error) throw error;
  return data;
}

/**
 * Update mutable profile fields for a user.
 *
 * @param {string} userId
 * @param {{ full_name?, username?, phone?, date_of_birth? }} dto
 * @returns {object} Updated user record
 */
export async function updateMyProfile(userId, dto) {
  // Check username uniqueness if changed
  if (dto.username) {
    const { data: clash } = await supabase
      .from('users')
      .select('id')
      .eq('username', dto.username)
      .neq('id', userId)
      .maybeSingle();

    if (clash) {
      const err = new Error('Username already taken');
      err.statusCode = 409;
      err.code = 'USERNAME_TAKEN';
      throw err;
    }
  }

  const { data, error } = await supabase
    .from('users')
    .update(dto)
    .eq('id', userId)
    .select('id, email, full_name, username, phone, date_of_birth, avatar_url, membership_type, updated_at')
    .single();

  if (error) throw error;
  return data;
}

/**
 * Upload an avatar to Supabase Storage and update the user's avatar_url.
 *
 * @param {string} userId
 * @param {Buffer} fileBuffer
 * @param {string} mimeType
 * @returns {{ avatar_url: string }}
 */
export async function uploadAvatar(userId, fileBuffer, mimeType) {
  const ext = mimeType.split('/')[1];
  const path = `${userId}/avatar.${ext}`;
  const bucket = env.SUPABASE_STORAGE_AVATARS_BUCKET;

  const { error: uploadError } = await supabase.storage
    .from(bucket)
    .upload(path, fileBuffer, { contentType: mimeType, upsert: true });

  if (uploadError) throw uploadError;

  const { data: { publicUrl } } = supabase.storage.from(bucket).getPublicUrl(path);

  await supabase.from('users').update({ avatar_url: publicUrl }).eq('id', userId);
  return { avatar_url: publicUrl };
}

/**
 * Get notification preferences for the user, creating defaults if not yet present.
 *
 * @param {string} userId
 * @returns {object} Notification preferences record
 */
export async function getMyPreferences(userId) {
  let { data, error } = await supabase
    .from('notification_preferences')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (!data && !error) {
    // Upsert default preferences
    const { data: created, error: createErr } = await supabase
      .from('notification_preferences')
      .insert({ user_id: userId })
      .select()
      .single();
    if (createErr) throw createErr;
    data = created;
  } else if (error) {
    throw error;
  }

  return data;
}

/**
 * Patch notification preferences for the user.
 *
 * @param {string} userId
 * @param {object} dto - Partial preferences object
 * @returns {object} Updated preferences record
 */
export async function updateMyPreferences(userId, dto) {
  const { data, error } = await supabase
    .from('notification_preferences')
    .upsert({ user_id: userId, ...dto }, { onConflict: 'user_id' })
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Aggregate stats for the authenticated user.
 *
 * @param {string} userId
 * @returns {{ total_trips, total_spent_lkr, average_rating, completed_trips, ongoing_trips }}
 */
export async function getMyStats(userId) {
  const [tripsResult, ratingsResult] = await Promise.all([
    supabase
      .from('trips')
      .select('id, fare_lkr, status')
      .eq('user_id', userId),
    supabase
      .from('ratings')
      .select('stars')
      .eq('user_id', userId),
  ]);

  if (tripsResult.error) throw tripsResult.error;

  const trips = tripsResult.data || [];
  const ratings = ratingsResult.data || [];

  const total_trips = trips.length;
  const completed_trips = trips.filter((t) => t.status === 'completed').length;
  const ongoing_trips = trips.filter((t) => t.status === 'ongoing').length;
  const total_spent_lkr = trips
    .filter((t) => t.fare_lkr != null)
    .reduce((sum, t) => sum + Number(t.fare_lkr), 0);

  const average_rating =
    ratings.length > 0
      ? +(ratings.reduce((sum, r) => sum + r.stars, 0) / ratings.length).toFixed(2)
      : null;

  return { total_trips, completed_trips, ongoing_trips, total_spent_lkr, average_rating };
}
