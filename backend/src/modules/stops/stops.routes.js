import { Router } from 'express';
import { validate } from '../../middleware/validate.middleware.js';
import { nearbyStopsSchema } from './stops.schema.js';
import * as controller from './stops.controller.js';

const router = Router();

// All stop endpoints are publicly readable
router.get('/',            controller.getAll);
router.get('/nearby',      validate(nearbyStopsSchema, 'query'), controller.getNearby);
router.get('/:id',         controller.getById);
router.get('/:id/routes',  controller.getRoutes);

export default router;
