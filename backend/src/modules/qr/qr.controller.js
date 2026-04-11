import * as qrService from './qr.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getMyQrCard(req, res, next) {
  try {
    const card = await qrService.getMyQrCard(req.user.id);
    return sendSuccess(res, card, 'QR card fetched');
  } catch (err) {
    next(err);
  }
}

export async function scanExit(req, res, next) {
  try {
    const result = await qrService.scanExit(req.user.id, req.body);
    return sendSuccess(res, result, result.message);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}
