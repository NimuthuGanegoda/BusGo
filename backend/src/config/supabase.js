import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';

/**
 * Service-role Supabase client.
 * Bypasses Row Level Security — use ONLY in server-side code, never expose to clients.
 */
export const supabase = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
    realtime: {
      params: {
        eventsPerSecond: 10,
      },
    },
  }
);

/**
 * Publish a message to a Supabase Realtime broadcast channel.
 *
 * @param {string} channel  - Channel name (e.g. 'bus-locations')
 * @param {string} event    - Event name  (e.g. 'location-update')
 * @param {object} payload  - JSON payload
 */
export async function broadcastToChannel(channel, event, payload) {
  const ch = supabase.channel(channel);
  await ch.send({ type: 'broadcast', event, payload });
  await supabase.removeChannel(ch);
}
