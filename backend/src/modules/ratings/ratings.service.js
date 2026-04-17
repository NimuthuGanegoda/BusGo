import { supabase } from '../../config/supabase.js';
import { predictRating } from '../../utils/ml.client.js';

// ── Exponential decay weight ───────────────────────────────────────────────
// λ = 0.1 → half-life ≈ 7 days (recent comments matter more)
const DECAY_LAMBDA = 0.1;

function decayWeight(createdAt) {
  const daysSince = (Date.now() - new Date(createdAt).getTime()) / (1000 * 60 * 60 * 24);
  return Math.exp(-DECAY_LAMBDA * daysSince);
}

// ── Weighted ML rating calculation ─────────────────────────────────────────
function calcWeightedRating(ratings) {
  const mlRatings = ratings.filter(r => r.ml_rating != null);
  if (!mlRatings.length) return null;

  let weightedSum = 0;
  let totalWeight = 0;

  for (const r of mlRatings) {
    const w = decayWeight(r.created_at);
    weightedSum += r.ml_rating * w;
    totalWeight += w;
  }

  return totalWeight > 0
    ? Math.round((weightedSum / totalWeight) * 10) / 10
    : null;
}

// ── Get my ratings ─────────────────────────────────────────────────────────
export async function getMyRatings(userId) {
  const { data, error } = await supabase
    .from('ratings')
    .select(`
      id, stars, tags, comment, ml_rating, ml_confidence, ml_context, created_at,
      trips ( id, boarded_at, bus_routes ( route_number, route_name ) ),
      buses ( id, bus_number, driver_name )
    `)
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data;
}

// ── Create rating (comment only — ML scores it) ────────────────────────────
export async function createRating(userId, dto) {
  // Verify trip belongs to user and is completed
  const { data: trip } = await supabase
    .from('trips')
    .select('id, status, bus_id')
    .eq('id', dto.trip_id)
    .eq('user_id', userId)
    .maybeSingle();

  if (!trip) {
    const err = new Error('Trip not found');
    err.statusCode = 404; err.code = 'TRIP_NOT_FOUND'; throw err;
  }
  if (trip.status !== 'completed') {
    const err = new Error('You can only rate completed trips');
    err.statusCode = 409; err.code = 'TRIP_NOT_COMPLETED'; throw err;
  }

  // Get driver history for ML context
  const { data: driverStats } = await supabase
    .from('ratings')
    .select('ml_rating')
    .eq('bus_id', dto.bus_id)
    .not('ml_rating', 'is', null);

  let driver_history = null;
  if (driverStats?.length) {
    const avg = driverStats.reduce((s, r) => s + r.ml_rating, 0) / driverStats.length;
    driver_history = { [dto.bus_id]: { avg_rating: avg, count: driverStats.length } };
  }

  // Call ML rating model if comment provided
  let mlResult = null;
  if (dto.comment?.trim()) {
    mlResult = await predictRating({
      comment:        dto.comment,
      timestamp:      new Date().toISOString(),
      driver_id:      dto.bus_id,
      driver_history,
    });
  }

  // Insert rating — stars defaults to 3 if not provided (comment-only flow)
  const { data, error } = await supabase
    .from('ratings')
    .insert({
      trip_id:       dto.trip_id,
      user_id:       userId,
      bus_id:        dto.bus_id,
      stars:         dto.stars ?? 3,
      tags:          dto.tags || [],
      comment:       dto.comment || null,
      ml_rating:     mlResult?.rating     || null,
      ml_confidence: mlResult?.confidence || null,
      ml_context:    mlResult?.context    || null,
    })
    .select()
    .single();

  if (error) {
    if (error.code === '23505') {
      const err = new Error('You have already rated this trip');
      err.statusCode = 409; err.code = 'RATING_EXISTS'; throw err;
    }
    throw error;
  }

  // Update rating aggregates after new rating
  await updateRatingAggregate(dto.bus_id).catch(e =>
    console.warn('Aggregate update failed:', e.message));

  return { ...data, ml_prediction: mlResult };
}

// ── Get bus rating stats (time-weighted) ───────────────────────────────────
export async function getBusRatingStats(busId) {
  const { data, error } = await supabase
    .from('ratings')
    .select('stars, ml_rating, created_at')
    .eq('bus_id', busId)
    .order('created_at', { ascending: false });

  if (error) throw error;

  const total          = data.length;
  const weightedRating = calcWeightedRating(data);
  const avg_stars      = total > 0
    ? +(data.reduce((s, r) => s + r.stars, 0) / total).toFixed(2)
    : null;

  const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  data.forEach(r => { breakdown[r.stars] = (breakdown[r.stars] || 0) + 1; });

  return {
    bus_id:               busId,
    total_ratings:        total,
    average_stars:        avg_stars,
    average_ml_rating:    weightedRating, // ← now time-weighted
    star_breakdown:       breakdown,
  };
}

// ── Get weighted rating for driver screen ──────────────────────────────────
export async function getWeightedDriverRating(busId) {
  // Active ratings (last 30 days) — full weight
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const { data: activeRatings } = await supabase
    .from('ratings')
    .select('id, stars, ml_rating, comment, tags, ml_confidence, ml_context, created_at')
    .eq('bus_id', busId)
    .gte('created_at', thirtyDaysAgo)
    .order('created_at', { ascending: false });

  // Archived aggregates (older than 30 days)
  const { data: aggregates } = await supabase
    .from('rating_aggregates')
    .select('avg_ml_rating, comment_count, weighted_score, period_start, period_end')
    .eq('bus_id', busId)
    .order('period_end', { ascending: false });

  // Calculate weighted score from active ratings
  const activeWeighted = calcWeightedRating(activeRatings ?? []);

  // Blend active + archived aggregate scores
  let finalScore = activeWeighted;
  if (aggregates?.length && activeRatings?.length === 0) {
    // Only archived data available
    finalScore = aggregates[0].weighted_score;
  } else if (aggregates?.length && activeWeighted != null) {
    // Blend: active gets 80% weight, archives get 20%
    const archiveScore = aggregates[0].weighted_score;
    finalScore = Math.round((activeWeighted * 0.8 + archiveScore * 0.2) * 10) / 10;
  }

  return {
    weighted_rating: finalScore,
    active_count:    activeRatings?.length ?? 0,
    recent_ratings:  (activeRatings ?? []).slice(0, 20),
    has_archive:     (aggregates?.length ?? 0) > 0,
  };
}

// ── Archive old ratings (run monthly) ─────────────────────────────────────
export async function archiveOldRatings(busId) {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  const ninetyDaysAgo = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000).toISOString();

  // Get ratings between 30-90 days old
  const { data: toArchive } = await supabase
    .from('ratings')
    .select('id, ml_rating, created_at')
    .eq('bus_id', busId)
    .lt('created_at', thirtyDaysAgo)
    .gte('created_at', ninetyDaysAgo)
    .not('ml_rating', 'is', null);

  if (!toArchive?.length) return { archived: 0 };

  // Calculate weighted score for this period
  const weightedScore = calcWeightedRating(toArchive);
  const avgMl = toArchive.reduce((s, r) => s + r.ml_rating, 0) / toArchive.length;

  // Store aggregate
  await supabase.from('rating_aggregates').insert({
    bus_id:        busId,
    period_start:  ninetyDaysAgo,
    period_end:    thirtyDaysAgo,
    avg_ml_rating: +avgMl.toFixed(2),
    comment_count: toArchive.length,
    weighted_score: weightedScore,
  });

  // Delete individual comments older than 90 days to save space
  await supabase
    .from('ratings')
    .delete()
    .eq('bus_id', busId)
    .lt('created_at', ninetyDaysAgo);

  return { archived: toArchive.length };
}

// ── Update aggregate after new rating ─────────────────────────────────────
async function updateRatingAggregate(busId) {
  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

  const { data: recent } = await supabase
    .from('ratings')
    .select('ml_rating, created_at')
    .eq('bus_id', busId)
    .gte('created_at', thirtyDaysAgo)
    .not('ml_rating', 'is', null);

  if (!recent?.length) return;

  const weighted = calcWeightedRating(recent);

  // Upsert current month aggregate
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const monthEnd   = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString();

  await supabase.from('rating_aggregates').upsert({
    bus_id:         busId,
    period_start:   monthStart,
    period_end:     monthEnd,
    avg_ml_rating:  weighted,
    comment_count:  recent.length,
    weighted_score: weighted,
  }, { onConflict: 'bus_id,period_start' });
}