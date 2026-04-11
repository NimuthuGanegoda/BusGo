import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import * as controller from './searches.controller.js';

const router = Router();
router.use(authenticate);

router.get('/',    controller.getRecent);
router.post('/',   controller.addRecent);
router.delete('/', controller.clearRecent);

export default router;
