import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { createRatingSchema } from './ratings.schema.js';
import * as controller from './ratings.controller.js';

const router = Router();
router.use(authenticate);

router.get('/',               controller.getMyRatings);
router.post('/',              validate(createRatingSchema), controller.createRating);
router.get('/bus/:busId',     controller.getBusStats);

export default router;
