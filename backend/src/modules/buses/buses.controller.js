import * as busesService from './buses.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getNearby(req, res, next) {
  try {
    const { lat, lng, radius } = req.query;
    const buses = await busesService.getNearbyBuses(Number(lat), Number(lng), Number(radius));
    return sendSuccess(res, buses, `${buses.length} nearby buses found`);
  } catch (err) {
    next(err);
  }
}

export async function getById(req, res, next) {
  try {
    const bus = await busesService.getBusById(req.params.id);
    return sendSuccess(res, bus, 'Bus fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function updateLocation(req, res, next) {
  try {
    const bus = await busesService.updateBusLocation(req.params.id, req.body);
    return sendSuccess(res, bus, 'Location updated');
  } catch (err) {
    next(err);
  }
}

export async function updateCrowd(req, res, next) {
  try {
    const bus = await busesService.updateBusCrowd(req.params.id, req.body.crowd_level);
    return sendSuccess(res, bus, 'Crowd level updated');
  } catch (err) {
    next(err);
  }
}
