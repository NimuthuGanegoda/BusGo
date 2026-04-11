import { env } from './env.js';

export const CONSTANTS = {
  // ── Auth ────────────────────────────────────────────────────────────────────
  PIN_LENGTH: 6,
  RESET_PIN_EXPIRES_MS: env.RESET_PIN_EXPIRES_MINUTES * 60 * 1000,
  QR_TOKEN_EXPIRES_MS: env.QR_TOKEN_EXPIRES_SECONDS * 1000,

  // ── Pagination ──────────────────────────────────────────────────────────────
  DEFAULT_PAGE: 1,
  DEFAULT_PAGE_SIZE: 20,
  MAX_PAGE_SIZE: 100,

  // ── Recent searches ─────────────────────────────────────────────────────────
  MAX_RECENT_SEARCHES: 5,

  // ── Bus location ────────────────────────────────────────────────────────────
  REALTIME_CHANNEL_BUS_LOCATIONS: 'bus-locations',

  // ── Nearby radius defaults (km) ─────────────────────────────────────────────
  DEFAULT_NEARBY_RADIUS_KM: 2,
  MAX_NEARBY_RADIUS_KM: 20,

  // ── Membership types ────────────────────────────────────────────────────────
  MEMBERSHIP_TYPES: ['standard', 'premium', 'student'],

  // ── Crowd levels ────────────────────────────────────────────────────────────
  CROWD_LEVELS: ['low', 'medium', 'high', 'full'],

  // ── Bus statuses ────────────────────────────────────────────────────────────
  BUS_STATUSES: ['active', 'inactive', 'breakdown'],

  // ── Trip statuses ───────────────────────────────────────────────────────────
  TRIP_STATUSES: ['ongoing', 'completed', 'cancelled'],

  // ── Emergency types ─────────────────────────────────────────────────────────
  EMERGENCY_TYPES: ['medical', 'criminal', 'breakdown', 'harassment', 'other'],

  // ── Emergency statuses ──────────────────────────────────────────────────────
  EMERGENCY_STATUSES: ['pending', 'acknowledged', 'resolved'],

  // ── Notification categories ─────────────────────────────────────────────────
  NOTIFICATION_CATEGORIES: ['bus_alert', 'trip', 'emergency', 'payment', 'general'],

  // ── Rating ──────────────────────────────────────────────────────────────────
  RATING_TAGS: ['Punctual', 'Safe Driving', 'Friendly', 'Clean Bus', 'Helpful'],
  MIN_STARS: 1,
  MAX_STARS: 5,

  // ── Supabase Storage ────────────────────────────────────────────────────────
  AVATAR_MAX_SIZE_BYTES: 5 * 1024 * 1024, // 5 MB
  AVATAR_ALLOWED_MIME_TYPES: ['image/jpeg', 'image/png', 'image/webp'],
};
