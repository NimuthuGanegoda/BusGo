import { z } from 'zod';

export const createEmergencySchema = z.object({
  alert_type:  z.enum(['medical', 'criminal', 'breakdown', 'harassment', 'other']),
  description: z.string().max(1000).optional(),
  bus_id:      z.string().optional(),
  trip_id:     z.string().optional(),
  latitude:    z.number().min(-90).max(90).optional(),
  longitude:   z.number().min(-180).max(180).optional(),
}).transform(data => ({
  ...data,
  bus_id:  data.bus_id  && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.bus_id)  ? data.bus_id  : undefined,
  trip_id: data.trip_id && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(data.trip_id) ? data.trip_id : undefined,
}));

export const updateEmergencyStatusSchema = z.object({
  status: z.enum(['pending', 'acknowledged', 'resolved']),
});




