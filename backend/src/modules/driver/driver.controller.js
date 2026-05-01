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

export async function updateStatus(req, res, next) {
  try {
    const bus = await driverService.updateDriverBusStatus(req.user.id, req.body.status);
    return sendSuccess(res, bus, `Bus status set to ${req.body.status}`);
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

export async function uploadLicense(req, res, next) {
  try {
    if (!req.file) {
      return sendError(res, 'License image is required', 400, 'NO_FILE');
    }
    const result = await driverService.uploadDriverLicense(
      req.user.id,
      req.file.buffer,
      req.file.mimetype,
    );
    return sendSuccess(res, result, 'License uploaded successfully');
  } catch (err) { next(err); }
}






