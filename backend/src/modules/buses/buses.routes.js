import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { nearbyBusesSchema, updateLocationSchema, updateCrowdSchema } from './buses.schema.js';
import * as controller from './buses.controller.js';

const router = Router();

// GET nearby — public (no auth required so passengers without accounts can also query)
router.get('/nearby', validate(nearbyBusesSchema, 'query'), controller.getNearby);
router.get('/:id',    controller.getById);

// Write operations require authentication
router.patch('/:id/location', authenticate, validate(updateLocationSchema), controller.updateLocation);
router.patch('/:id/crowd',    authenticate, validate(updateCrowdSchema),    controller.updateCrowd);

export default router;
