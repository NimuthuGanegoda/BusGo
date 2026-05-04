import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { nearbyBusesSchema, updateLocationSchema, updateCrowdSchema } from './buses.schema.js';
import * as controller from './buses.controller.js';
import * as busesService from './buses.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

const router = Router();

// GET nearby — public (no auth required so passengers without accounts can also query)
router.get('/nearby', validate(nearbyBusesSchema, 'query'), controller.getNearby);
router.get('/:id',    controller.getById);

// Write operations require authentication
router.patch('/:id/location', authenticate, validate(updateLocationSchema), controller.updateLocation);
router.patch('/:id/crowd',    authenticate, validate(updateCrowdSchema),    controller.updateCrowd);

// Recall a bus (sets status to recalled)
router.patch('/:id/recall', authenticate, async (req, res, next) => {
  try {
    const data = await busesService.recallBus(req.params.id, req.user.id);
    return sendSuccess(res, data, `Bus ${data.bus_number} recalled`);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
});

// Re-deploy a recalled bus
router.patch('/:id/deploy', authenticate, async (req, res, next) => {
  try {
    const data = await busesService.deployBus(req.params.id, req.user.id);
    return sendSuccess(res, data, `Bus ${data.bus_number} deployed`);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
});

export default router;







