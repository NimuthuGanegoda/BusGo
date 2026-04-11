import { z } from 'zod';
import { CONSTANTS } from '../../config/constants.js';

export const nearbyBusesSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(CONSTANTS.MAX_NEARBY_RADIUS_KM).default(CONSTANTS.DEFAULT_NEARBY_RADIUS_KM),
});

export const updateLocationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  heading: z.number().min(0).max(360).optional(),
  speed_kmh: z.number().min(0).optional(),
});

export const updateCrowdSchema = z.object({
  crowd_level: z.enum(['low', 'medium', 'high', 'full']),
});
