import * as emergencyService from './emergency.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';

export async function getAlerts(req, res, next) {
  try {
    const alerts = await emergencyService.getMyAlerts(req.user.id);
    return sendSuccess(res, alerts, 'Emergency alerts fetched');
  } catch (err) {
    next(err);
  }
}

export async function createAlert(req, res, next) {
  try {
    const alert = await emergencyService.createAlert(req.user.id, req.body);
    return sendSuccess(res, alert, 'Emergency alert sent', 201);
  } catch (err) {
    next(err);
  }
}

export async function updateStatus(req, res, next) {
  try {
    const alert = await emergencyService.updateAlertStatus(req.params.id, req.user.id, req.body.status);
    return sendSuccess(res, alert, 'Alert status updated');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}
