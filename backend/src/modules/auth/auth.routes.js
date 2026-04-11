import { Router } from 'express';
import { validate } from '../../middleware/validate.middleware.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';
import * as controller from './auth.controller.js';
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  forgotPasswordRequestSchema,
  forgotPasswordVerifySchema,
  forgotPasswordResetSchema,
} from './auth.schema.js';

const router = Router();

// Apply strict rate limiting to all auth routes
router.use(authLimiter);

router.post('/register',                  validate(registerSchema),                controller.register);
router.post('/login',                     validate(loginSchema),                   controller.login);
router.post('/logout',                    controller.logout);                      // accepts optional body
router.post('/refresh',                   validate(refreshSchema),                 controller.refresh);
router.post('/forgot-password/request',   validate(forgotPasswordRequestSchema),   controller.forgotPasswordRequest);
router.post('/forgot-password/verify',    validate(forgotPasswordVerifySchema),    controller.forgotPasswordVerify);
router.post('/forgot-password/reset',     validate(forgotPasswordResetSchema),     controller.forgotPasswordReset);

export default router;
