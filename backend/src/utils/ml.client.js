/**
 * ml.client.js
 * ─────────────
 * Thin HTTP client that calls the Python BUSGO ML microservice.
 * All 3 models are accessed here so the rest of the backend
 * never needs to know the ML service URL or payload shapes.
 */

import { env } from '../config/env.js';
import { logger } from './logger.js';

const ML_BASE = env.ML_SERVICE_URL || 'http://localhost:8000';
const TIMEOUT_MS = 8000;

/**
 * Internal fetch wrapper with timeout and JSON parsing.
 *
 * @param {string} path   - e.g. '/ml/rating'
 * @param {object} body   - JSON payload
 * @returns {Promise<object>} Parsed response JSON
 */
async function mlPost(path, body) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    const res = await fetch(`${ML_BASE}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: controller.signal,
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'ML service error' }));
      throw new Error(err.error || `ML service responded ${res.status}`);
    }

    return res.json();
  } catch (err) {
    if (err.name === 'AbortError') {
      logger.warn(`ML service timeout on ${path}`);
      throw new Error('ML service timeout');
    }
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

// ── Model 1 ───────────────────────────────────────────────────────────────────

/**
 * Predict a driver rating (1–10) from a passenger comment.
 *
 * @param {object} opts
 * @param {string}  opts.comment
 * @param {string?} opts.timestamp        - ISO string e.g. "2026-04-07 08:30:00"
 * @param {boolean?} opts.is_raining
 * @param {boolean?} opts.is_peak
 * @param {boolean?} opts.is_weekend
 * @param {boolean?} opts.is_night
 * @param {string?}  opts.driver_id
 * @param {object?}  opts.driver_history  - { [driver_id]: { avg_rating, count } }
 * @returns {Promise<{ rating, confidence, base_pred, adjustment, context, cleaned }>}
 */
export async function predictRating(opts) {
  try {
    return await mlPost('/ml/rating', opts);
  } catch (err) {
    logger.warn(`Rating ML call failed — using fallback: ${err.message}`);
    return null; // Caller handles null gracefully
  }
}

// ── Model 2 ───────────────────────────────────────────────────────────────────

/**
 * Predict ETA in minutes for a bus to reach a target stop.
 *
 * @param {object} opts
 * @param {string}  opts.bus_number
 * @param {number}  opts.dist_km
 * @param {number}  opts.stops_remaining
 * @param {number}  opts.speed_kmh
 * @param {boolean} opts.is_raining
 * @param {number}  opts.hour             - 0–23
 * @param {number?} opts.route_encoded
 * @param {number?} opts.road_type_encoded
 * @param {number?} opts.dwell_at_last_stop_s
 * @returns {Promise<{ eta_minutes, eta_seconds, context }>}
 */
export async function predictETA(opts) {
  try {
    return await mlPost('/ml/eta', opts);
  } catch (err) {
    logger.warn(`ETA ML call failed — using fallback: ${err.message}`);
    // Fallback: naive estimate = distance / average_speed (25 km/h)
    const fallback = Math.round((opts.dist_km / 25) * 60 * 10) / 10;
    return { eta_minutes: fallback, eta_seconds: fallback * 60, context: { fallback: true } };
  }
}

// ── Model 3 ───────────────────────────────────────────────────────────────────

/**
 * Run an emergency alert through the two-stage prioritization pipeline.
 *
 * @param {object} opts
 * @param {string} opts.alert_id
 * @param {string} opts.bus_id
 * @param {string} opts.emergency_type - Must match one of the 5 enum values
 * @param {string} opts.comment
 * @returns {Promise<{ priority, priority_label, action, is_false_alert, false_prob, confidence }>}
 */
export async function prioritizeAlert(opts) {
  // Map DB enum values to the ML model's expected format
  const typeMap = {
    medical:    'Medical Emergency',
    criminal:   'Criminal Activity',
    breakdown:  'Bus Breakdown',
    harassment: 'Harassment',
    other:      'Other',
  };

  try {
    return await mlPost('/ml/alert-priority', {
      ...opts,
      emergency_type: typeMap[opts.emergency_type] || 'Other',
    });
  } catch (err) {
    logger.warn(`Alert priority ML call failed — using fallback: ${err.message}`);
    // Fallback: use base priority from type map
    const basePriority = { medical: 4, criminal: 3, breakdown: 2, harassment: 3, other: 2 };
    const p = basePriority[opts.emergency_type] || 2;
    return {
      priority: p,
      priority_label: ['','FALSE','LOW','MEDIUM','HIGH','CRITICAL'][p],
      action: 'Manual review required (ML service unavailable)',
      is_false_alert: false,
      false_prob: 0,
      confidence: 0,
    };
  }
}
