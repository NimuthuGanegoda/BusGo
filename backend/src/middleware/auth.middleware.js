import { verifyAccessToken } from '../utils/jwt.utils.js';
import { sendError } from '../utils/response.utils.js';
import { supabase } from '../config/supabase.js';

/**
 * Middleware: verify Bearer access token and attach req.user (including role).
 */
export async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendError(res, 'Missing or malformed Authorization header', 401, 'UNAUTHORIZED');
    }

    const token = authHeader.slice(7);
    let decoded;
    try {
      decoded = verifyAccessToken(token);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return sendError(res, 'Access token expired', 401, 'TOKEN_EXPIRED');
      }
      return sendError(res, 'Invalid access token', 401, 'INVALID_TOKEN');
    }

    const { data: user, error } = await supabase
      .from('users')
      .select('id, email, full_name, username, phone, avatar_url, membership_type, role, is_active')
      .eq('id', decoded.id)
      .single();

    if (error || !user) {
      return sendError(res, 'User not found', 401, 'USER_NOT_FOUND');
    }

    if (!user.is_active) {
      return sendError(res, 'Account is deactivated', 403, 'ACCOUNT_INACTIVE');
    }

    req.user = user;
    next();
  } catch (err) {
    next(err);
  }
}



