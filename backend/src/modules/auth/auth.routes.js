import { Router } from 'express';
import { validate } from '../../middleware/validate.middleware.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';
import * as controller from './auth.controller.js';
import multer from 'multer';
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  forgotPasswordRequestSchema,
  forgotPasswordVerifySchema,
  forgotPasswordResetSchema,
} from './auth.schema.js';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

// Apply strict rate limiting to all auth routes
router.use(authLimiter);

router.post('/register',                  validate(registerSchema),                controller.register);
router.post('/login',                     validate(loginSchema),                   controller.login);
router.post('/logout',                    controller.logout);
router.post('/refresh',                   validate(refreshSchema),                 controller.refresh);
router.post('/forgot-password/request',   validate(forgotPasswordRequestSchema),   controller.forgotPasswordRequest);
router.post('/forgot-password/verify',    validate(forgotPasswordVerifySchema),    controller.forgotPasswordVerify);
router.post('/forgot-password/reset',     validate(forgotPasswordResetSchema),     controller.forgotPasswordReset);

// ── Public license upload (no token needed — driver just registered) ──────────
router.post('/upload-license', upload.single('license'), controller.uploadLicense);

export default router;