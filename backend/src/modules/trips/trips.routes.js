import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { listTripsSchema, createTripSchema, alightTripSchema } from './trips.schema.js';
import * as controller from './trips.controller.js';

const router = Router();
router.use(authenticate);

router.get('/',              validate(listTripsSchema, 'query'), controller.listTrips);
router.get('/:id',           controller.getTripById);
router.post('/',             validate(createTripSchema),         controller.createTrip);
router.patch('/:id/alight',  validate(alightTripSchema),         controller.alightTrip);

export default router;
