import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { createEmergencySchema, updateEmergencyStatusSchema } from './emergency.schema.js';
import * as controller from './emergency.controller.js';

const router = Router();
router.use(authenticate);

router.get('/',               controller.getAlerts);
router.post('/',              validate(createEmergencySchema),       controller.createAlert);
router.patch('/:id/status',   validate(updateEmergencyStatusSchema), controller.updateStatus);

export default router;
