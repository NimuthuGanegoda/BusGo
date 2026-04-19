import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import morgan from 'morgan';

import { env } from './config/env.js';
import { logger } from './utils/logger.js';
import { generalLimiter } from './middleware/rateLimiter.middleware.js';
import { errorHandler, notFoundHandler } from './middleware/error.middleware.js';
import paymentsRoutes from './modules/payments/payments.routes.js';

// ── Module routers ────────────────────────────────────────────────────────────
import authRoutes          from './modules/auth/auth.routes.js';
import usersRoutes         from './modules/users/users.routes.js';
import qrRoutes            from './modules/qr/qr.routes.js';
import busesRoutes         from './modules/buses/buses.routes.js';
import routesRoutes        from './modules/routes/routes.routes.js';
import stopsRoutes         from './modules/stops/stops.routes.js';
import tripsRoutes         from './modules/trips/trips.routes.js';
import ratingsRoutes       from './modules/ratings/ratings.routes.js';
import emergencyRoutes     from './modules/emergency/emergency.routes.js';
import notificationsRoutes from './modules/notifications/notifications.routes.js';
import searchesRoutes      from './modules/searches/searches.routes.js';
// New modules
import adminRoutes         from './modules/admin/admin.routes.js';
import driverRoutes        from './modules/driver/driver.routes.js';
import etaRoutes           from './modules/eta/eta.routes.js';

const app = express();



// ── Security headers ──────────────────────────────────────────────────────────
app.use(helmet());

// ── CORS ──────────────────────────────────────────────────────────────────────
const allowedOrigins = env.CORS_ORIGINS.split(',').map((o) => o.trim());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) return callback(null, true);
      if (env.NODE_ENV === 'development') {
        const isLocal = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
        if (isLocal) return callback(null, true);
      }
      callback(new Error(`CORS: origin '${origin}' not allowed`));
    },
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  })
);

// ── Request parsing ────────────────────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

// ── HTTP request logging ───────────────────────────────────────────────────────
app.use(
  morgan('combined', {
    stream: { write: (msg) => logger.http(msg.trim()) },
    skip: (req) => req.url === '/health',
  })
);

// ── General rate limiter ──────────────────────────────────────────────────────
app.use('/api', generalLimiter);

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), env: env.NODE_ENV });
});

// ── API Routes ────────────────────────────────────────────────────────────────
app.use('/api/auth',              authRoutes);
app.use('/api/users',             usersRoutes);
app.use('/api/qr',                qrRoutes);
app.use('/api/buses',             busesRoutes);
app.use('/api/payments',          paymentsRoutes);
app.use('/api/routes',            routesRoutes);
app.use('/api/stops',             stopsRoutes);
app.use('/api/trips',             tripsRoutes);
app.use('/api/ratings',           ratingsRoutes);
app.use('/api/emergency',         emergencyRoutes);
app.use('/api/notifications',     notificationsRoutes);
app.use('/api/searches/recent',   searchesRoutes);
app.use('/api/admin',             adminRoutes);
app.use('/api/driver',            driverRoutes);
app.use('/api/eta',               etaRoutes);

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use(notFoundHandler);

// ── Global error handler ──────────────────────────────────────────────────────
app.use(errorHandler);

export default app;
