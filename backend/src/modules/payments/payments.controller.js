import * as service from './payments.service.js';

export async function getRoutes(req, res, next) {
  try {
    const data = await service.getRoutesWithPricing();
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function getRouteStops(req, res, next) {
  try {
    const data = await service.getRouteStops(req.params.routeId);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function calculate(req, res, next) {
  try {
    const { route_id, from_stop, to_stop } = req.query;
    if (!route_id || !from_stop || !to_stop) {
      return res.status(400).json({ success: false, message: 'route_id, from_stop, to_stop required' });
    }
    const data = await service.calculateFare(route_id, from_stop, to_stop);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function initiate(req, res, next) {
  try {
    const data = await service.initiatePayment(req.user.id, req.body);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function notify(req, res, next) {
  try {
    await service.handlePaymentNotify(req.body);
    res.status(200).send('OK');
  } catch (e) {
    console.error('[Payment Notify Error]', e);
    res.status(200).send('OK');
  }
}

export async function myTickets(req, res, next) {
  try {
    const data = await service.getMyTickets(req.user.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function getTicket(req, res, next) {
  try {
    const data = await service.getTicketById(req.params.id, req.user.id);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}

export async function verifyScan(req, res, next) {
  try {
    const { qr_token, route_id } = req.body;
    if (!qr_token) {
      return res.status(400).json({ success: false, message: 'qr_token required' });
    }
    const data = await service.verifyScanPayment(qr_token, route_id || null);
    res.json({ success: true, data });
  } catch (e) { next(e); }
}







