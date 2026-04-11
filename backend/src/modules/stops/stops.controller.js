import * as stopsService from './stops.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getAll(req, res, next) {
  try {
    const stops = await stopsService.getAllStops();
    return sendSuccess(res, stops, 'Stops fetched');
  } catch (err) {
    next(err);
  }
}

export async function getById(req, res, next) {
  try {
    const stop = await stopsService.getStopById(req.params.id);
    return sendSuccess(res, stop, 'Stop fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function getNearby(req, res, next) {
  try {
    const { lat, lng, radius } = req.query;
    const stops = await stopsService.getNearbyStops(Number(lat), Number(lng), Number(radius));
    return sendSuccess(res, stops, `${stops.length} nearby stops found`);
  } catch (err) {
    next(err);
  }
}

export async function getRoutes(req, res, next) {
  try {
    const routes = await stopsService.getStopRoutes(req.params.id);
    return sendSuccess(res, routes, 'Stop routes fetched');
  } catch (err) {
    next(err);
  }
}
