import { z } from 'zod';

export const searchRoutesSchema = z.object({
  q: z.string().min(1, 'Search query is required').trim(),
});
