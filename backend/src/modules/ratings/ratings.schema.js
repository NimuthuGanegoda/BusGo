import { z } from 'zod';
import { CONSTANTS } from '../../config/constants.js';

export const createRatingSchema = z.object({
  trip_id: z.string().uuid('trip_id must be a UUID'),
  bus_id:  z.string().uuid('bus_id must be a UUID'),
  stars:   z.number().int().min(CONSTANTS.MIN_STARS).max(CONSTANTS.MAX_STARS),
  tags:    z.array(z.string()).default([]),
  comment: z.string().max(500).optional(),
});
