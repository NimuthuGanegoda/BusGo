// Load environment variables before anything else
import './config/env.js';

import http from 'http';
import app from './app.js';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';
import { supabase } from './config/supabase.js';

const server = http.createServer(app);

/**
 * Gracefully shut down the HTTP server.
 *
 * @param {string} signal - OS signal name (e.g. 'SIGTERM')
 */
function shutdown(signal) {
  logger.info(`${signal} received — shutting down gracefully`);
  server.close((err) => {
    if (err) {
      logger.error('Error during shutdown', { error: err.message });
      process.exit(1);
    }
    logger.info('HTTP server closed');
    process.exit(0);
  });

  // Force exit after 10 s if still open
  setTimeout(() => {
    logger.error('Forcing shutdown after timeout');
    process.exit(1);
  }, 10_000).unref();
}

async function start() {
  // Verify Supabase connectivity
  try {
    const { error } = await supabase.from('users').select('id').limit(1);
    if (error) throw error;
    logger.info('✅ Supabase connection verified');
  } catch (err) {
    logger.error('❌ Cannot connect to Supabase', { message: err.message });
    process.exit(1);
  }

  server.listen(env.PORT, () => {
    logger.info(`🚀 BusGo API running on port ${env.PORT} [${env.NODE_ENV}]`);
    logger.info(`   Health check: http://localhost:${env.PORT}/health`);
  });

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));

  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled promise rejection', { reason: String(reason) });
    shutdown('unhandledRejection');
  });

  process.on('uncaughtException', (err) => {
    logger.error('Uncaught exception', { message: err.message, stack: err.stack });
    shutdown('uncaughtException');
  });
}

start();
