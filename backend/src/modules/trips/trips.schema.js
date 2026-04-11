import { z } from 'zod';

export const listTripsSchema = z.object({
  status: z.enum(['ongoing', 'completed', 'cancelled']).optional(),
  from: z.string().date().optional(),
  to: z.string().date().optional(),
  page: z.coerce.number().int().positive().default(1),
  page_size: z.coerce.number().int().positive().max(100).default(20),
});

export const createTripSchema = z.object({
  bus_id: z.string().uuid('bus_id must be a UUID'),
  route_id: z.string().uuid('route_id must be a UUID'),
  boarding_stop_id: z.string().uuid().optional(),
});

export const alightTripSchema = z.object({
  alighting_stop_id: z.string().uuid().optional(),
  fare_lkr: z.number().positive().optional(),
});
