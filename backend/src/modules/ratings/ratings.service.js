import { supabase } from '../../config/supabase.js';
import { predictRating } from '../../utils/ml.client.js';

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

export async function createRating(userId, dto) {
  // Verify trip belongs to user and is completed
  const { data: trip } = await supabase
    .from('trips')
    .select('id, status, bus_id')
    .eq('id', dto.trip_id)
    .eq('user_id', userId)
    .maybeSingle();

  if (!trip) {
    const err = new Error('Trip not found'); err.statusCode = 404; err.code = 'TRIP_NOT_FOUND'; throw err;
  }
  if (trip.status !== 'completed') {
    const err = new Error('You can only rate completed trips'); err.statusCode = 409; err.code = 'TRIP_NOT_COMPLETED'; throw err;
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

  // Call ML rating model if comment is provided
  let mlResult = null;
  if (dto.comment?.trim()) {
    mlResult = await predictRating({
      comment:        dto.comment,
      timestamp:      new Date().toISOString(),
      driver_id:      dto.bus_id,
      driver_history,
    });
  }

  // Insert rating
  const { data, error } = await supabase
    .from('ratings')
    .insert({
      trip_id:       dto.trip_id,
      user_id:       userId,
      bus_id:        dto.bus_id,
      stars:         dto.stars,
      tags:          dto.tags || [],
      comment:       dto.comment || null,
      ml_rating:     mlResult?.rating || null,
      ml_confidence: mlResult?.confidence || null,
      ml_context:    mlResult?.context || null,
    })
    .select()
    .single();

  if (error) {
    if (error.code === '23505') {
      const err = new Error('You have already rated this trip'); err.statusCode = 409; err.code = 'RATING_EXISTS'; throw err;
    }
    throw error;
  }

  return { ...data, ml_prediction: mlResult };
}

export async function getBusRatingStats(busId) {
  const { data, error } = await supabase
    .from('ratings')
    .select('stars, ml_rating')
    .eq('bus_id', busId);

  if (error) throw error;

  const total = data.length;
  const avg_stars = total > 0 ? +(data.reduce((s, r) => s + r.stars, 0) / total).toFixed(2) : null;
  const ml_data   = data.filter(r => r.ml_rating !== null);
  const avg_ml    = ml_data.length > 0 ? +(ml_data.reduce((s, r) => s + r.ml_rating, 0) / ml_data.length).toFixed(2) : null;
  const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  data.forEach(r => { breakdown[r.stars] = (breakdown[r.stars] || 0) + 1; });

  return { bus_id: busId, total_ratings: total, average_stars: avg_stars, average_ml_rating: avg_ml, star_breakdown: breakdown };
}
