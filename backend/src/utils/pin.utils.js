import bcrypt from 'bcryptjs';
import { env } from '../config/env.js';
import { CONSTANTS } from '../config/constants.js';

/**
 * Generate a cryptographically random N-digit numeric PIN.
 *
 * @param {number} length - Number of digits (default: 6)
 * @returns {string} Zero-padded PIN string
 */
export function generatePin(length = CONSTANTS.PIN_LENGTH) {
  const max = Math.pow(10, length);
  const pin = Math.floor(Math.random() * max);
  return String(pin).padStart(length, '0');
}

/**
 * Hash a PIN using bcrypt (same rounds as passwords).
 *
 * @param {string} pin
 * @returns {Promise<string>} bcrypt hash
 */
export async function hashPin(pin) {
  const salt = await bcrypt.genSalt(env.BCRYPT_ROUNDS);
  return bcrypt.hash(pin, salt);
}

/**
 * Verify a plain PIN against its bcrypt hash.
 *
 * @param {string} pin
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
export async function verifyPin(pin, hash) {
  return bcrypt.compare(pin, hash);
}
