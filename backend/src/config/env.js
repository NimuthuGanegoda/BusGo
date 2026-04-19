import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(5000),

  // Supabase
  SUPABASE_URL: z.string().url('SUPABASE_URL must be a valid URL'),
  SUPABASE_ANON_KEY: z.string().min(1, 'SUPABASE_ANON_KEY is required'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1, 'SUPABASE_SERVICE_ROLE_KEY is required'),

  // JWT
  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 chars'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 chars'),
  JWT_RESET_SECRET: z.string().min(32, 'JWT_RESET_SECRET must be at least 32 chars'),
  JWT_ACCESS_EXPIRES_IN: z.coerce.number().default(900),
  JWT_REFRESH_EXPIRES_IN: z.coerce.number().default(604800),
  JWT_RESET_EXPIRES_IN: z.coerce.number().default(300),

  // bcrypt
  BCRYPT_ROUNDS: z.coerce.number().min(10).max(14).default(12),

  // Rate limiting
  RATE_LIMIT_AUTH_WINDOW_MS: z.coerce.number().default(900000),
  RATE_LIMIT_AUTH_MAX: z.coerce.number().default(10),
  RATE_LIMIT_GENERAL_WINDOW_MS: z.coerce.number().default(60000),
  RATE_LIMIT_GENERAL_MAX: z.coerce.number().default(100),

  // QR
  QR_TOKEN_EXPIRES_SECONDS: z.coerce.number().default(30),

  // Reset PIN
  RESET_PIN_EXPIRES_MINUTES: z.coerce.number().default(10),

  // Supabase Storage
  SUPABASE_STORAGE_AVATARS_BUCKET: z.string().default('avatars'),

  // CORS
  CORS_ORIGINS: z.string().default('http://localhost:3000'),

  // ML Microservice
  ML_SERVICE_URL: z.string().url().default('http://localhost:8000'),

  // Payment (WebXPay)
  PAYMENT_SANDBOX: z.string().default('true'),
  WEBXPAY_MERCHANT_ID: z.string().default(''),
  WEBXPAY_MERCHANT_SECRET: z.string().default(''),
  WEBXPAY_RETURN_URL: z.string().default(''),
  WEBXPAY_NOTIFY_URL: z.string().default(''),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  parsed.error.issues.forEach((issue) => {
    console.error(`   ${issue.path.join('.')}: ${issue.message}`);
  });
  process.exit(1);
}

export const env = parsed.data;