import { z } from 'zod';

export const updateProfileSchema = z.object({
  full_name: z.string().min(2).trim().optional(),
  username: z.string().min(3).trim().optional(),
  phone: z.string().min(7).trim().optional(),
  date_of_birth: z.string().date().optional(),
}).refine((data) => Object.keys(data).length > 0, {
  message: 'At least one field must be provided',
});

export const updatePreferencesSchema = z.object({
  bus_alerts: z.boolean().optional(),
  trip_updates: z.boolean().optional(),
  emergency_alerts: z.boolean().optional(),
  payment_notifications: z.boolean().optional(),
  promotions: z.boolean().optional(),
}).refine((data) => Object.keys(data).length > 0, {
  message: 'At least one preference must be provided',
});
