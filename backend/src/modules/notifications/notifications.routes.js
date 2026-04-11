import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { listNotificationsSchema } from './notifications.schema.js';
import * as controller from './notifications.controller.js';

const router = Router();
router.use(authenticate);

router.get('/',                  validate(listNotificationsSchema, 'query'), controller.listNotifications);
router.patch('/read-all',        controller.markAllAsRead);
router.patch('/:id/read',        controller.markAsRead);
router.delete('/:id',            controller.deleteNotification);

export default router;
