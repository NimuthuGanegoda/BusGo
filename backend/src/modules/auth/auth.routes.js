import dns from 'dns';
dns.setDefaultResultOrder('ipv4first');
import { Router } from 'express';
import { validate } from '../../middleware/validate.middleware.js';
import { authLimiter } from '../../middleware/rateLimiter.middleware.js';
import { authenticate } from '../../middleware/auth.middleware.js';
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
import { z } from 'zod';
import { hashPassword } from '../../utils/password.utils.js';
import { hashPin, verifyPin } from '../../utils/pin.utils.js';
import { signResetToken } from '../../utils/jwt.utils.js';
import { supabase } from '../../config/supabase.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';
import { verifyPassengerIdentity } from './auth.service.js';

const router = Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 5 * 1024 * 1024 } });

router.use((req, res, next) => {
  if (req.path === '/admin/resolve-recovery') return next();
  authLimiter(req, res, next);
});

router.post('/register', (req, res, next) => {
  console.log('[RAW BODY]', JSON.stringify(req.body));
  const result = registerSchema.safeParse(req.body);
  if (!result.success) console.log('[VALIDATION ERRORS]', JSON.stringify(result.error.issues));
  next();
}, validate(registerSchema), controller.register);
router.post('/login',   validate(loginSchema),   controller.login);
router.post('/logout',  controller.logout);
router.post('/refresh', validate(refreshSchema), controller.refresh);

// ── Email verification ──────────────────────────────────────────────────────
router.post('/verify-email/resend',
  validate(z.object({ email: z.string().email() })),
  controller.resendVerificationPin
);
router.post('/verify-email',
  validate(z.object({ email: z.string().email(), pin: z.string().length(6) })),
  controller.verifyEmail
);

// ── Forgot password (old email PIN flow — kept for compatibility) ────────────
router.post('/forgot-password/request', validate(forgotPasswordRequestSchema), controller.forgotPasswordRequest);
router.post('/forgot-password/verify',  validate(forgotPasswordVerifySchema),  controller.forgotPasswordVerify);
router.post('/forgot-password/reset',   validate(forgotPasswordResetSchema),   controller.forgotPasswordReset);

// ── NEW: Passenger forgot password via recovery PIN + security questions ─────
router.post('/forgot-password/verify-identity', async (req, res, next) => {
  try {
    const { email, recovery_pin, answer_1, answer_2, answer_3 } = req.body;

    if (!email || !recovery_pin || !answer_1 || !answer_2 || !answer_3) {
      return sendError(res, 'All fields are required', 400, 'MISSING_FIELDS');
    }

    const result = await verifyPassengerIdentity(
      email, recovery_pin, answer_1, answer_2, answer_3
    );

    return sendSuccess(res, result, 'Identity verified successfully.');
  } catch (err) { next(err); }
});

// ── Change password (logged-in user) ─────────────────────────────────────────
router.post('/change-password',
  authenticate,
  validate(z.object({
    current_password: z.string().min(1),
    new_password:     z.string().min(8),
    confirm_password: z.string().min(8),
  })),
  controller.changePassword
);

// ── License upload ────────────────────────────────────────────────────────────
router.post('/upload-license', upload.single('license'), controller.uploadLicense);

// ── Admin first-login setup ───────────────────────────────────────────────────
router.post('/admin/setup', authenticate, async (req, res, next) => {
  try {
    const { new_password, recovery_pin, answer_1, answer_2, answer_3 } = req.body;
    const userId = req.user.id;

    if (!new_password || !recovery_pin || !answer_1 || !answer_2 || !answer_3) {
      return sendError(res, 'All fields are required', 400, 'MISSING_FIELDS');
    }
    if (!/^\d{6}$/.test(recovery_pin)) {
      return sendError(res, 'Recovery PIN must be exactly 6 digits', 400, 'INVALID_PIN');
    }
    if (new_password.length < 8) {
      return sendError(res, 'Password must be at least 8 characters', 400, 'WEAK_PASSWORD');
    }

    const password_hash     = await hashPassword(new_password);
    const recovery_pin_hash = await hashPin(recovery_pin);
    const answer_1_hash     = await hashPin(answer_1.trim().toLowerCase());
    const answer_2_hash     = await hashPin(answer_2.trim().toLowerCase());
    const answer_3_hash     = await hashPin(answer_3.trim().toLowerCase());

    const { error } = await supabase.from('users').update({
      password_hash,
      recovery_pin_hash,
      security_answer_1_hash: answer_1_hash,
      security_answer_2_hash: answer_2_hash,
      security_answer_3_hash: answer_3_hash,
      is_first_login: false,
    }).eq('id', userId);

    if (error) throw error;

    await supabase.from('security_audit_log').insert({
      event_type: 'ADMIN_FIRST_LOGIN_SETUP',
      user_id:    userId,
      email:      req.user.email,
      details:    { completed_at: new Date().toISOString() },
      severity:   'info',
    });

    return sendSuccess(res, {}, 'Account setup complete. Welcome to BUSGO Axis.');
  } catch (err) { next(err); }
});

// ── Admin recovery request ────────────────────────────────────────────────────
router.post('/admin/recovery-request', async (req, res, next) => {
  try {
    const { email, recovery_pin, answer_1, answer_2, answer_3 } = req.body;

    if (!email || !recovery_pin || !answer_1 || !answer_2 || !answer_3) {
      return sendError(res, 'All fields are required', 400, 'MISSING_FIELDS');
    }

    const { data: user } = await supabase.from('users')
      .select('id, email, full_name, role, recovery_pin_hash, security_answer_1_hash, security_answer_2_hash, security_answer_3_hash')
      .eq('email', email.toLowerCase().trim())
      .maybeSingle();

    const FAIL = () => sendError(res, 'Verification failed. Please check your PIN and answers.', 401, 'VERIFICATION_FAILED');

    if (!user || !['admin', 'developer'].includes(user.role)) return FAIL();
    if (!user.recovery_pin_hash || !user.security_answer_1_hash) return FAIL();

    const pinOk = await verifyPin(recovery_pin, user.recovery_pin_hash);
    if (!pinOk) return FAIL();

    const a1Ok = await verifyPin(answer_1.trim().toLowerCase(), user.security_answer_1_hash);
    const a2Ok = await verifyPin(answer_2.trim().toLowerCase(), user.security_answer_2_hash);
    const a3Ok = await verifyPin(answer_3.trim().toLowerCase(), user.security_answer_3_hash);
    if (!a1Ok || !a2Ok || !a3Ok) return FAIL();

    await supabase.from('security_audit_log').insert({
      event_type: 'ADMIN_RECOVERY_REQUEST',
      user_id:    user.id,
      email:      user.email,
      details: {
        full_name:   user.full_name,
        verified_at: new Date().toISOString(),
        status:      'pending_developer_approval',
      },
      severity: 'warning',
    });

    return sendSuccess(res, {}, 'Identity verified. A developer will provide a temporary password within 24 hours.');
  } catch (err) { next(err); }
});

export default router;

// ── Developer approves recovery request ──────────────────────────────────────
router.post('/admin/resolve-recovery', authenticate, async (req, res, next) => {
  try {
    const { user_id, email, temp_password } = req.body;

    if (req.user.role !== 'developer') {
      return sendError(res, 'Only developers can approve recovery requests', 403, 'FORBIDDEN');
    }
    if (!user_id || !email || !temp_password) {
      return sendError(res, 'Missing required fields', 400, 'MISSING_FIELDS');
    }

    const password_hash = await hashPassword(temp_password);
    await supabase.from('users').update({
      password_hash,
      is_first_login: true,
    }).eq('id', user_id);

    const { data: adminUser } = await supabase
      .from('users').select('full_name').eq('id', user_id).maybeSingle();

    const { sendAdminTempPassword } = await import('../../utils/email.utils.js');
    try {
      await sendAdminTempPassword(email, temp_password, adminUser?.full_name || 'Admin');
    } catch (emailErr) {
      console.error('[Recovery] Email failed:', emailErr.message);
    }

    await supabase.from('security_audit_log').insert({
      event_type: 'ADMIN_RECOVERY_RESOLVED',
      user_id:    req.user.id,
      email:      req.user.email,
      details: {
        resolved_admin_id:    user_id,
        resolved_admin_email: email,
        resolved_at:          new Date().toISOString(),
        status:               'resolved',
      },
      severity: 'info',
    });

    return sendSuccess(res, {}, 'Recovery approved and temporary password sent via email.');
  } catch (err) { next(err); }
});