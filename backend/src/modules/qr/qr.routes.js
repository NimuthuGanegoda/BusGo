import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { z } from 'zod';
import * as qrService from './qr.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

const router = Router();
router.use(authenticate);

// Passenger: get their QR card
// ?force=true  → always generate a new token (refresh button)
// ?force=false → only generate if expired (normal screen load)
router.get('/my-card', async (req, res, next) => {
  try {
    const force = req.query.force === 'true';
    const card  = await qrService.getMyQrCard(req.user.id, force);
    return sendSuccess(res, card, 'QR card fetched');
  } catch (err) { next(err); }
});

// Scanner app (driver): scan passenger QR on boarding → creates trip
router.post('/scan-in',
  validate(z.object({
    scanned_token:     z.string().uuid('scanned_token must be a UUID'),
    bus_id:            z.string().uuid().optional(),
    route_id:          z.string().uuid().optional(),
    boarding_stop_id:  z.string().uuid().optional(),
    alighting_stop_id: z.string().uuid().optional(),
  })),
  async (req, res, next) => {
    try {
      const result = await qrService.scanIn(req.body.scanned_token, req.user.id, req.body, req);
      return sendSuccess(res, result, result.message, 201);
    } catch (err) {
      if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
      next(err);
    }
  }
);

// Scanner app (driver): scan passenger QR on alighting → completes trip
router.post('/scan-exit',
  validate(z.object({
    scanned_token:     z.string().uuid('scanned_token must be a UUID'),
    alighting_stop_id: z.string().uuid().optional(),
    fare_lkr:          z.number().positive().optional(),
  })),
  async (req, res, next) => {
    try {
      const result = await qrService.scanExit(req.user.id, req.body);
      return sendSuccess(res, result, result.message);
    } catch (err) {
      if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
      next(err);
    }
  }
);

export default router;

