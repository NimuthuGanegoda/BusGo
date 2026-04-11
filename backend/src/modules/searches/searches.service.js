import { supabase } from '../../config/supabase.js';
import { CONSTANTS } from '../../config/constants.js';

/**
 * Return the most recent searches for the authenticated user (max 5, newest first).
 *
 * @param {string} userId
 * @returns {Array<object>}
 */
export async function getRecentSearches(userId) {
  const { data, error } = await supabase
    .from('recent_searches')
    .select('id, query, created_at')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(CONSTANTS.MAX_RECENT_SEARCHES);

  if (error) throw error;
  return data;
}

/**
 * Save a new search query for the user.
 * The DB trigger automatically deletes the oldest if more than 5 exist.
 * Duplicate queries are replaced (delete old, insert new) to keep list fresh.
 *
 * @param {string} userId
 * @param {string} query
 * @returns {object} Created search record
 */
export async function addRecentSearch(userId, query) {
  // Remove duplicate if exists so the new one floats to top
  await supabase
    .from('recent_searches')
    .delete()
    .eq('user_id', userId)
    .eq('query', query);

  const { data, error } = await supabase
    .from('recent_searches')
    .insert({ user_id: userId, query })
    .select()
    .single();

  if (error) throw error;
  return data;
}

/**
 * Clear all recent searches for the user.
 *
 * @param {string} userId
 * @returns {{ deleted_count: number }}
 */
export async function clearRecentSearches(userId) {
  const { data, error } = await supabase
    .from('recent_searches')
    .delete()
    .eq('user_id', userId)
    .select('id');

  if (error) throw error;
  return { deleted_count: data?.length || 0 };
}
