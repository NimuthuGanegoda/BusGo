import * as tripsService from './trips.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function listTrips(req, res, next) {
  try {
    const { trips, pagination } = await tripsService.listTrips(req.user.id, req.query);
    return sendSuccess(res, trips, 'Trips fetched', 200, pagination);
  } catch (err) {
    next(err);
  }
}

export async function getTripById(req, res, next) {
  try {
    const trip = await tripsService.getTripById(req.params.id, req.user.id);
    return sendSuccess(res, trip, 'Trip fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function createTrip(req, res, next) {
  try {
    const trip = await tripsService.createTrip(req.user.id, req.body);
    return sendSuccess(res, trip, 'Trip started', 201);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function alightTrip(req, res, next) {
  try {
    const trip = await tripsService.alightTrip(req.params.id, req.user.id, req.body);
    return sendSuccess(res, trip, 'Trip completed. Please rate your ride!');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}
