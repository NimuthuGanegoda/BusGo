import * as routesService from './routes.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getAll(req, res, next) {
  try {
    const routes = await routesService.getAllRoutes();
    return sendSuccess(res, routes, 'Routes fetched');
  } catch (err) {
    next(err);
  }
}

export async function getById(req, res, next) {
  try {
    const route = await routesService.getRouteById(req.params.id);
    return sendSuccess(res, route, 'Route fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function search(req, res, next) {
  try {
    const routes = await routesService.searchRoutes(req.query.q);
    return sendSuccess(res, routes, `${routes.length} route(s) found`);
  } catch (err) {
    next(err);
  }
}

export async function getStops(req, res, next) {
  try {
    const stops = await routesService.getRouteStops(req.params.id);
    return sendSuccess(res, stops, 'Route stops fetched');
  } catch (err) {
    next(err);
  }
}

export async function getBuses(req, res, next) {
  try {
    const buses = await routesService.getRouteBuses(req.params.id);
    return sendSuccess(res, buses, 'Route buses fetched');
  } catch (err) {
    next(err);
  }
}
