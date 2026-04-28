import crypto from 'crypto';
import { supabase } from '../../config/supabase.js';
import { env } from '../../config/env.js';

// ── Price calculation ─────────────────────────────────────────────────────────

export async function calculateFare(routeId, boardingStopId, alightingStopId) {
  const { data: pricing } = await supabase
    .from('trip_pricing')
    .select('base_fare, per_stop')
    .eq('route_id', routeId)
    .single();

  const baseFare = pricing?.base_fare ?? 20.0;
  const perStop  = pricing?.per_stop  ?? 5.0;

  const { data: stops } = await supabase
    .from('bus_stop_routes')
    .select('stop_id, stop_order')
    .eq('route_id', routeId)
    .in('stop_id', [boardingStopId, alightingStopId]);

  if (!stops || stops.length < 2) {
    const err = new Error('One or both stops not found on this route');
    err.statusCode = 400;
    throw err;
  }

  const boardingOrder  = stops.find(s => s.stop_id === boardingStopId)?.stop_order ?? 0;
  const alightingOrder = stops.find(s => s.stop_id === alightingStopId)?.stop_order ?? 0;
  const stopCount = Math.abs(alightingOrder - boardingOrder);

  if (stopCount === 0) {
    const err = new Error('Boarding and alighting stops cannot be the same');
    err.statusCode = 400;
    throw err;
  }

  return {
    route_id: routeId,
    boarding_stop: boardingStopId,
    alighting_stop: alightingStopId,
    stop_count: stopCount,
    base_fare: baseFare,
    per_stop: perStop,
    amount: parseFloat((baseFare + (stopCount * perStop)).toFixed(2)),
    currency: 'LKR',
  };
}

// ── Routes with pricing ───────────────────────────────────────────────────────

export async function getRoutesWithPricing() {
  const { data, error } = await supabase
    .from('bus_routes')
    .select(`id, route_number, route_name, origin, destination, color, is_active,
             trip_pricing ( base_fare, per_stop )`)
    .eq('is_active', true)
    .order('route_number');
  if (error) throw error;

  return data.map(route => ({
    ...route,
    base_fare: route.trip_pricing?.[0]?.base_fare ?? 20.0,
    per_stop:  route.trip_pricing?.[0]?.per_stop  ?? 5.0,
  }));
}

// ── Stops for a route (ordered) ───────────────────────────────────────────────

export async function getRouteStops(routeId) {
  const { data, error } = await supabase
    .from('bus_stop_routes')
    .select(`stop_order, bus_stops ( id, stop_name, latitude, longitude )`)
    .eq('route_id', routeId)
    .order('stop_order');
  if (error) throw error;

  return data.map(item => ({
    id: item.bus_stops.id,
    stop_name: item.bus_stops.stop_name,
    latitude: item.bus_stops.latitude,
    longitude: item.bus_stops.longitude,
    stop_order: item.stop_order,
  }));
}

// ── Initiate payment ──────────────────────────────────────────────────────────

export async function initiatePayment(userId, body) {
  const { route_id, boarding_stop_id, alighting_stop_id } = body;
  const fare = await calculateFare(route_id, boarding_stop_id, alighting_stop_id);

  const { data: stopNames } = await supabase
    .from('bus_stops')
    .select('id, stop_name')
    .in('id', [boarding_stop_id, alighting_stop_id]);

  const boardingName  = stopNames?.find(s => s.id === boarding_stop_id)?.stop_name ?? '';
  const alightingName = stopNames?.find(s => s.id === alighting_stop_id)?.stop_name ?? '';

  const { data: user } = await supabase
    .from('users')
    .select('full_name, email, phone')
    .eq('id', userId)
    .single();

  const qrData           = crypto.randomUUID();
  const verificationCode = String(Math.floor(100000 + Math.random() * 900000));
  const orderId          = `BUSGO-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

  const validUntil = new Date();
  validUntil.setHours(23, 59, 59, 999);

  // Determine if sandbox mode (for student project demo)
  const isSandbox = env.PAYMENT_SANDBOX !== 'false';

  const { data: ticket, error } = await supabase
    .from('trip_tickets')
    .insert({
      user_id: userId,
      route_id,
      boarding_stop_id,
      alighting_stop_id,
      boarding_stop_name: boardingName,
      alighting_stop_name: alightingName,
      stop_count: fare.stop_count,
      amount: fare.amount,
      currency: 'LKR',
      payment_method: isSandbox ? 'sandbox' : 'webxpay',
      payment_status: isSandbox ? 'paid' : 'pending', // Sandbox auto-pays
      payhere_order_id: orderId,
      verification_code: verificationCode,
      qr_data: qrData,
      valid_until: validUntil.toISOString(),
    })
    .select()
    .single();

  if (error) throw error;

  return {
    ticket_id: ticket.id,
    order_id: orderId,
    amount: fare.amount,
    currency: 'LKR',
    stop_count: fare.stop_count,
    boarding: boardingName,
    alighting: alightingName,
    is_sandbox: isSandbox,
    // Ticket data (for immediate display in sandbox mode)
    ticket: {
      id: ticket.id,
      qr_data: qrData,
      verification_code: verificationCode,
      valid_until: validUntil.toISOString(),
      payment_status: ticket.payment_status,
      boarding_stop_name: boardingName,
      alighting_stop_name: alightingName,
      stop_count: fare.stop_count,
      amount: fare.amount,
      route_id,
    },
    // WEBXPAY parameters (for live mode)
    webxpay: isSandbox ? null : {
      merchant_id: env.WEBXPAY_MERCHANT_ID,
      order_id: orderId,
      amount: fare.amount.toFixed(2),
      currency: 'LKR',
      description: `BUSGO Ticket: ${boardingName} → ${alightingName}`,
      customer_name: user?.full_name || 'Passenger',
      customer_email: user?.email || '',
      customer_phone: user?.phone || '',
      return_url: `${env.WEBXPAY_RETURN_URL || 'busgo://payment-complete'}`,
      notify_url: `${env.WEBXPAY_NOTIFY_URL || 'http://localhost:5000/api/payments/notify'}`,
    },
  };
}

// ── Payment notification webhook ──────────────────────────────────────────────

export async function handlePaymentNotify(body) {
  const { order_id, status, payment_id } = body;

  const paymentStatus = status === 'success' ? 'paid'
    : status === 'pending' ? 'pending'
    : 'failed';

  const { data, error } = await supabase
    .from('trip_tickets')
    .update({
      payment_status: paymentStatus,
      payhere_payment_id: payment_id || null,
    })
    .eq('payhere_order_id', order_id)
    .select()
    .single();

  if (error) throw error;
  console.log(`[Payment] Ticket ${order_id} → ${paymentStatus}`);
  return data;
}

// ── Get user's tickets ────────────────────────────────────────────────────────

export async function getMyTickets(userId) {
  const { data, error } = await supabase
    .from('trip_tickets')
    .select(`id, route_id, boarding_stop_name, alighting_stop_name,
             stop_count, amount, currency, payment_status,
             verification_code, qr_data, valid_from, valid_until, created_at,
             bus_routes ( route_number, route_name, color )`)
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(20);
  if (error) throw error;
  return data;
}

export async function getTicketById(ticketId, userId) {
  const { data, error } = await supabase
    .from('trip_tickets')
    .select(`*, bus_routes ( route_number, route_name, origin, destination, color )`)
    .eq('id', ticketId)
    .eq('user_id', userId)
    .single();
  if (error || !data) {
    const err = new Error('Ticket not found');
    err.statusCode = 404;
    throw err;
  }
  return data;
}

// ── Scanner verification ──────────────────────────────────────────────────────

export async function verifyScanPayment(qrToken, routeId) {
  console.log('[SCAN DEBUG] qr_token received:', JSON.stringify(qrToken));
  console.log('[SCAN DEBUG] route_id received:', JSON.stringify(routeId));
  let query = supabase
    .from('trip_tickets')
    .select('id, user_id, boarding_stop_name, alighting_stop_name, amount, verification_code')
    .eq('qr_data', qrToken)
    .eq('payment_status', 'paid')
    .gte('valid_until', new Date().toISOString())
    .is('verified_at', null)
    .order('created_at', { ascending: false })
    .limit(1);

  // Only filter by route if provided
  if (routeId) {
    query = query.eq('route_id', routeId);
  }

  const { data: ticket } = await query.maybeSingle();

  if (ticket) {
    await supabase
      .from('trip_tickets')
      .update({ verified_at: new Date().toISOString() })
      .eq('id', ticket.id);

    return {
      payment_status: 'PAID',
      ticket: {
        id: ticket.id,
        from: ticket.boarding_stop_name,
        to: ticket.alighting_stop_name,
        amount: ticket.amount,
        code: ticket.verification_code,
      },
    };
  }

  // Check if ticket exists but was already used or expired
  const { data: usedTicket } = await supabase
    .from('trip_tickets')
    .select('id, verified_at, valid_until')
    .eq('qr_data', qrToken)
    .maybeSingle();

  if (usedTicket) {
    if (usedTicket.verified_at) {
      return { payment_status: 'UNKNOWN', message: 'Ticket already used' };
    }
    if (new Date(usedTicket.valid_until) < new Date()) {
      return { payment_status: 'UNKNOWN', message: 'Ticket expired' };
    }
  }

  return { payment_status: 'CASH', message: 'No prepaid ticket found' };
}


