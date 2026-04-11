import { createLogger, format, transports } from 'winston';
import { env } from '../config/env.js';

const { combine, timestamp, colorize, printf, json, errors } = format;

// Human-readable format for development
const devFormat = combine(
  colorize({ all: true }),
  timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp, stack, ...meta }) => {
    let msg = `${timestamp} [${level}]: ${message}`;
    if (stack) msg += `\n${stack}`;
    const extras = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
    return msg + extras;
  })
);

// Structured JSON format for production (log aggregators)
const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  json()
);

export const logger = createLogger({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: env.NODE_ENV === 'production' ? prodFormat : devFormat,
  transports: [
    new transports.Console(),
    // In production you can add file or cloud transports here:
    // new transports.File({ filename: 'logs/error.log', level: 'error' }),
    // new transports.File({ filename: 'logs/combined.log' }),
  ],
  exitOnError: false,
});
