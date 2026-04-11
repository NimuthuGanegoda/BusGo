import { z } from 'zod';
import { CONSTANTS } from '../../config/constants.js';

export const nearbyStopsSchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(CONSTANTS.MAX_NEARBY_RADIUS_KM).default(CONSTANTS.DEFAULT_NEARBY_RADIUS_KM),
});
