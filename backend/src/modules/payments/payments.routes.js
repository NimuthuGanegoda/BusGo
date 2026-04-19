import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware.js';
import * as controller from './payments.controller.js';

const router = Router();

// Public: payment notification webhook
router.post('/notify', controller.notify);

// Protected
router.use(authenticate);
router.get('/routes',               controller.getRoutes);
router.get('/route/:routeId/stops', controller.getRouteStops);
router.get('/calculate',            controller.calculate);
router.post('/initiate',            controller.initiate);
router.get('/my-tickets',           controller.myTickets);
router.get('/ticket/:id',           controller.getTicket);
router.post('/verify-scan',         controller.verifyScan);

export default router;
