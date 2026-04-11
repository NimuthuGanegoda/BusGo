import bcrypt from 'bcryptjs';
import { env } from '../config/env.js';

/**
 * Hash a plain-text password using bcrypt.
 *
 * @param {string} plainPassword
 * @returns {Promise<string>} bcrypt hash
 */
export async function hashPassword(plainPassword) {
  const salt = await bcrypt.genSalt(env.BCRYPT_ROUNDS);
  return bcrypt.hash(plainPassword, salt);
}

/**
 * Compare a plain-text password against a bcrypt hash.
 *
 * @param {string} plainPassword
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
export async function comparePassword(plainPassword, hash) {
  return bcrypt.compare(plainPassword, hash);
}
