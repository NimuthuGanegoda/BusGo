import { z } from 'zod';

export const listNotificationsSchema = z.object({
  category: z.enum(['bus_alert', 'trip', 'emergency', 'payment', 'general']).optional(),
  unread_only: z.coerce.boolean().default(false),
  page: z.coerce.number().int().positive().default(1),
  page_size: z.coerce.number().int().positive().max(100).default(20),
});
