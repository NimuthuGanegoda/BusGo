import { Router } from 'express';
import multer from 'multer';
import { authenticate } from '../../middleware/auth.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import { updateProfileSchema, updatePreferencesSchema } from './users.schema.js';
import * as controller from './users.controller.js';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// All user routes require authentication
router.use(authenticate);

router.get('/me',                  controller.getMe);
router.patch('/me',                validate(updateProfileSchema), controller.updateMe);
router.patch('/me/avatar',         upload.single('avatar'),       controller.uploadAvatar);
router.get('/me/preferences',      controller.getMyPreferences);
router.patch('/me/preferences',    validate(updatePreferencesSchema), controller.updateMyPreferences);
router.get('/me/stats',            controller.getMyStats);

export default router;
