import { z } from 'zod';

export const createEmergencySchema = z.object({
  alert_type: z.enum(['medical', 'criminal', 'breakdown', 'harassment', 'other']),
  description: z.string().max(1000).optional(),
  bus_id: z.string().uuid().optional(),
  trip_id: z.string().uuid().optional(),
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
});

export const updateEmergencyStatusSchema = z.object({
  status: z.enum(['pending', 'acknowledged', 'resolved']),
});
