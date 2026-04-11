import { Router } from 'express';
import { validate } from '../../middleware/validate.middleware.js';
import { searchRoutesSchema } from './routes.schema.js';
import * as controller from './routes.controller.js';

const router = Router();

// All route endpoints are publicly readable (no auth required)
router.get('/',            controller.getAll);
router.get('/search',      validate(searchRoutesSchema, 'query'), controller.search);
router.get('/:id',         controller.getById);
router.get('/:id/stops',   controller.getStops);
router.get('/:id/buses',   controller.getBuses);

export default router;
