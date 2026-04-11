// driver.controller.js
import * as driverService from './driver.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getProfile(req, res, next) {
  try {
    const profile = await driverService.getDriverProfile(req.user.id);
    return sendSuccess(res, profile, 'Driver profile fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function getMyBus(req, res, next) {
  try {
    const bus = await driverService.getAssignedBus(req.user.id);
    return sendSuccess(res, bus, bus ? 'Assigned bus fetched' : 'No bus assigned');
  } catch (err) { next(err); }
}

export async function updateLocation(req, res, next) {
  try {
    const bus = await driverService.updateDriverLocation(req.user.id, req.body);
    return sendSuccess(res, bus, 'Location updated');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function updateCrowd(req, res, next) {
  try {
    const bus = await driverService.updateCrowdLevel(req.user.id, req.body.crowd_level);
    return sendSuccess(res, bus, 'Crowd level updated');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function getMyRating(req, res, next) {
  try {
    const stats = await driverService.getDriverRating(req.user.id);
    return sendSuccess(res, stats, 'Driver rating fetched');
  } catch (err) { next(err); }
}

export async function getCurrentTrip(req, res, next) {
  try {
    const trip = await driverService.getDriverCurrentTrip(req.user.id);
    return sendSuccess(res, trip, 'Current trip data fetched');
  } catch (err) { next(err); }
}
