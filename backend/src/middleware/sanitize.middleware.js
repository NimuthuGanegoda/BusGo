/**
 * Input sanitization middleware.
 * Strips HTML tags and dangerous characters from request body, query, and params.
 * Placed early in the middleware chain to clean all inputs before they reach handlers.
 */

// Simple but effective HTML/script tag stripper
function stripTags(str) {
  if (typeof str !== 'string') return str;
  return str
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove <script> tags
    .replace(/<[^>]*>/g, '')         // Remove all HTML tags
    .replace(/javascript:/gi, '')     // Remove javascript: protocol
    .replace(/on\w+\s*=/gi, '')       // Remove event handlers (onclick=, etc.)
    .replace(/data:\s*text\/html/gi, '') // Remove data:text/html
    .trim();
}

// Recursively sanitize all string values in an object
function sanitizeObject(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'string') return stripTags(obj);
  if (Array.isArray(obj)) return obj.map(sanitizeObject);
  if (typeof obj === 'object') {
    const cleaned = {};
    for (const [key, value] of Object.entries(obj)) {
      // Don't sanitize password fields (they might contain special chars)
      if (key === 'password' || key === 'new_password' || key === 'password_hash') {
        cleaned[key] = value;
      } else {
        cleaned[key] = sanitizeObject(value);
      }
    }
    return cleaned;
  }
  return obj;
}

/**
 * Express middleware: sanitize req.body, req.query, req.params
 */
export function sanitizeInputs(req, res, next) {
  if (req.body) req.body = sanitizeObject(req.body);
  if (req.query) req.query = sanitizeObject(req.query);
  if (req.params) req.params = sanitizeObject(req.params);
  next();
}