import * as ratingsService from './ratings.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getMyRatings(req, res, next) {
  try {
    const ratings = await ratingsService.getMyRatings(req.user.id);
    return sendSuccess(res, ratings, 'Ratings fetched');
  } catch (err) {
    next(err);
  }
}

export async function createRating(req, res, next) {
  try {
    const rating = await ratingsService.createRating(req.user.id, req.body);
    return sendSuccess(res, rating, 'Rating submitted. Thank you!', 201);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function getBusStats(req, res, next) {
  try {
    const stats = await ratingsService.getBusRatingStats(req.params.busId);
    return sendSuccess(res, stats, 'Bus rating stats fetched');
  } catch (err) {
    next(err);
  }
}
