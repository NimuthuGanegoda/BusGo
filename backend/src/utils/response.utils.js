/**
 * Send a standardised success response.
 *
 * @param {import('express').Response} res
 * @param {object}  data        - Payload to return
 * @param {string}  message     - Human-readable success message
 * @param {number}  statusCode  - HTTP status code (default 200)
 * @param {object?} pagination  - Optional pagination metadata
 */
export function sendSuccess(res, data = {}, message = 'OK', statusCode = 200, pagination = null) {
  const body = { success: true, message, data };
  if (pagination) body.pagination = pagination;
  return res.status(statusCode).json(body);
}

/**
 * Send a standardised error response.
 *
 * @param {import('express').Response} res
 * @param {string}  message    - Human-readable error message
 * @param {number}  statusCode - HTTP status code (default 500)
 * @param {string}  code       - Machine-readable error code
 * @param {object?} errors     - Optional field-level validation errors
 */
export function sendError(res, message = 'Internal Server Error', statusCode = 500, code = 'INTERNAL_ERROR', errors = null) {
  const body = { success: false, message, code };
  if (errors) body.errors = errors;
  return res.status(statusCode).json(body);
}

/**
 * Build a pagination metadata object.
 *
 * @param {number} total    - Total number of records
 * @param {number} page     - Current page (1-based)
 * @param {number} pageSize - Records per page
 */
export function buildPagination(total, page, pageSize) {
  return {
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize),
    hasNext: page * pageSize < total,
    hasPrev: page > 1,
  };
}
