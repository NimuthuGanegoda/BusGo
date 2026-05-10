import * as tripsService from './trips.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';
import { supabase } from '../../config/supabase.js';

export async function listTrips(req, res, next) {
  try {
    const { trips, pagination } = await tripsService.listTrips(req.user.id, req.query);
    return sendSuccess(res, trips, 'Trips fetched', 200, pagination);
  } catch (err) {
    next(err);
  }
}

export async function getTripById(req, res, next) {
  try {
    const trip = await tripsService.getTripById(req.params.id, req.user.id);
    return sendSuccess(res, trip, 'Trip fetched');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function createTrip(req, res, next) {
  try {
    const trip = await tripsService.createTrip(req.user.id, req.body);
    return sendSuccess(res, trip, 'Trip started', 201);
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function alightTrip(req, res, next) {
  try {
    const trip = await tripsService.alightTrip(req.params.id, req.user.id, req.body);
    return sendSuccess(res, trip, 'Trip completed. Please rate your ride!');
  } catch (err) {
    if (err.statusCode) return sendError(res, err.message, err.statusCode, err.code);
    next(err);
  }
}

export async function disputeTrip(req, res, next) {
  try {
    const { id }      = req.params;
    const passengerId = req.user.id;

    // Verify trip belongs to this passenger
    const { data: trip, error: tripErr } = await supabase
      .from('trips')
      .select('id, user_id, bus_id, route_id, status, boarded_at')
      .eq('id', id)
      .eq('user_id', passengerId)
      .maybeSingle();

    if (tripErr || !trip) {
      return sendError(res, 'Trip not found', 404, 'TRIP_NOT_FOUND');
    }

    // Log the dispute to admin_audit_logs
    const { error: logErr } = await supabase
      .from('admin_audit_logs')
      .insert({
        admin_id:   passengerId,
        action:     'PASSENGER_DISPUTED_BOARDING',
        table_name: 'trips',
        record_id:  id,
        metadata:   {
          trip_id:      id,
          passenger_id: passengerId,
          bus_id:       trip.bus_id,
          route_id:     trip.route_id,
          trip_status:  trip.status,
          boarded_at:   trip.boarded_at,
          disputed_at:  new Date().toISOString(),
          source:       'passenger_app',
          note:         'Passenger indicated they did not board this bus',
        },
      });

    if (logErr) throw logErr;

    return sendSuccess(res, {}, 'Dispute logged. Our team will review it.');
  } catch (err) {
    next(err);
  }
}
