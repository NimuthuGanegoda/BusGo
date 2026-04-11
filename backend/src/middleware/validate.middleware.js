import { sendError } from '../utils/response.utils.js';

/**
 * Factory that returns an Express middleware which validates the request
 * body (or query / params) against a Zod schema.
 *
 * @param {import('zod').ZodSchema} schema - Zod schema to validate against
 * @param {'body'|'query'|'params'} source  - Where to read data from (default: 'body')
 * @returns {import('express').RequestHandler}
 *
 * @example
 *   router.post('/register', validate(registerSchema), authController.register);
 *   router.get('/nearby', validate(nearbySchema, 'query'), busController.nearby);
 */
export function validate(schema, source = 'body') {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);
    if (!result.success) {
      const errors = result.error.issues.map((issue) => ({
        field: issue.path.join('.'),
        message: issue.message,
      }));
      return sendError(res, 'Validation failed', 422, 'VALIDATION_ERROR', errors);
    }
    // Replace raw input with parsed (coerced / trimmed) values
    req[source] = result.data;
    next();
  };
}
