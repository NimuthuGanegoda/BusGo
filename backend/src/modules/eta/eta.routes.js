// eta.controller.js
import * as etaService from './eta.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getBusETA(req, res, next) {
  try {
    const { busId, stopId } = req.params;
    const context = {
      is_raining: req.query.is_raining === 'true',
    };
    const result = await etaService.getBusETA(busId, stopId, context);
    return sendSuccess(res, result, `ETA: ~${result.eta_minutes} min`);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function getRouteETAs(req, res, next) {
  try {
    const { routeId, stopId } = req.params;
    const context = { is_raining: req.query.is_raining === 'true' };
    const results = await etaService.getRouteETAs(routeId, stopId, context);
    return sendSuccess(res, results, `${results.length} bus ETA(s) calculated`);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

// ─── eta.routes.js (inlined) ──────────────────────────────────────────────────
import { Router } from 'express';

const router = Router();

// Public — passengers and drivers need ETA without auth (e.g. map screen before login)
router.get('/bus/:busId/stop/:stopId',      getBusETA);
router.get('/route/:routeId/stop/:stopId',  getRouteETAs);

export default router;



