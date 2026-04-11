import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().email('Invalid email address').toLowerCase().trim(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  full_name: z.string().min(2, 'Full name must be at least 2 characters').trim(),
  username: z.string().min(3, 'Username must be at least 3 characters').trim().optional(),
  phone: z.string().min(7, 'Invalid phone number').trim().optional(),
  date_of_birth: z.string().date('Invalid date format (YYYY-MM-DD)').optional(),
  membership_type: z.enum(['standard', 'premium', 'student']).default('standard'),
});

export const loginSchema = z.object({
  email: z.string().email('Invalid email address').toLowerCase().trim(),
  password: z.string().min(1, 'Password is required'),
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(1, 'Refresh token is required'),
});

export const forgotPasswordRequestSchema = z.object({
  email: z.string().email('Invalid email address').toLowerCase().trim(),
});

export const forgotPasswordVerifySchema = z.object({
  email: z.string().email().toLowerCase().trim(),
  pin: z.string().length(6, 'PIN must be exactly 6 digits').regex(/^\d+$/, 'PIN must be numeric'),
});

export const forgotPasswordResetSchema = z.object({
  reset_token: z.string().min(1, 'Reset token is required'),
  new_password: z.string().min(8, 'New password must be at least 8 characters'),
  confirm_password: z.string().min(1, 'Confirm password is required'),
}).refine((data) => data.new_password === data.confirm_password, {
  message: 'Passwords do not match',
  path: ['confirm_password'],
});
