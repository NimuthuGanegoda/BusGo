import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import { requireAdmin } from '../../middleware/admin.middleware.js';
import { validate } from '../../middleware/validate.middleware.js';
import * as controller from './admin.controller.js';
import { z } from 'zod';

const router = Router();

// All admin routes require valid JWT + admin role
router.use(authenticate, requireAdmin);

// ── Pagination query schema (reused across list routes) ──────────────────────
const pageSchema = z.object({
  page:      z.coerce.number().int().positive().default(1),
  page_size: z.coerce.number().int().positive().max(100).default(20),
});

// ── Dashboard ────────────────────────────────────────────────────────────────
router.get('/dashboard', controller.getDashboard);

// ── User Management ──────────────────────────────────────────────────────────
router.get('/users',
  validate(pageSchema.extend({
    role:      z.enum(['passenger', 'driver', 'admin']).optional(),
    is_active: z.coerce.boolean().optional(),
    search:    z.string().optional(),
  }), 'query'),
  controller.listUsers
);
router.get('/users/:id',                   controller.getUserById);
router.patch('/users/:id',                 controller.updateUser);
router.patch('/users/:id/deactivate',      controller.deactivateUser);
router.patch('/users/:id/reactivate',      controller.reactivateUser);
router.delete('/users/:id',                controller.deleteUser);
router.get('/users/:id/license-url',       controller.getDriverLicenseUrl);


// ── Bus Management ───────────────────────────────────────────────────────────
router.get('/buses',
  validate(pageSchema.extend({
    status:   z.enum(['active', 'inactive', 'breakdown']).optional(),
    route_id: z.string().uuid().optional(),
  }), 'query'),
  controller.listBuses
);
router.post('/buses',        controller.createBus);
router.patch('/buses/:id',   controller.updateBus);
router.delete('/buses/:id',  controller.deleteBus);

// ── Emergency Alerts ─────────────────────────────────────────────────────────
router.get('/emergency',
  validate(pageSchema.extend({
    status:     z.enum(['pending', 'acknowledged', 'resolved']).optional(),
    alert_type: z.enum(['medical', 'criminal', 'breakdown', 'harassment', 'other']).optional(),
  }), 'query'),
  controller.listAlerts
);
router.patch('/emergency/:id/status',
  validate(z.object({ status: z.enum(['pending', 'acknowledged', 'resolved']) })),
  controller.updateAlertStatus
);

// ── Fleet Management ─────────────────────────────────────────────────────────
router.get('/fleet/standby',         controller.getStandbyBuses);
router.patch('/fleet/:id/deploy',
  validate(z.object({ route_id: z.string().uuid() })),
  controller.deployBus
);
router.patch('/fleet/:id/recall',    controller.recallBus);

// ── Route CRUD ───────────────────────────────────────────────────────────────
router.post('/routes',               controller.createRoute);
router.patch('/routes/:id',          controller.updateRoute);
router.delete('/routes/:id',         controller.deleteRoute);

// ── Audit Logs ───────────────────────────────────────────────────────────────
router.get('/audit-logs',
  validate(pageSchema.extend({
    admin_id: z.string().uuid().optional(),
    action:   z.string().optional(),
  }), 'query'),
  controller.getAuditLogs
);

router.get('/security-logs', controller.getSecurityLogs);
router.post('/send-service-update',
  validate(z.object({
    driver_id: z.string().uuid(),
    title:     z.string().min(1).max(100),
    body:      z.string().min(1).max(1000),
  })),
  controller.sendServiceUpdate
);

router.post('/send-service-update',
  validate(z.object({
    driver_id: z.string().uuid(),
    title:     z.string().min(1).max(100),
    body:      z.string().min(1).max(1000),
  })),
  controller.sendServiceUpdate
);
export default router;








