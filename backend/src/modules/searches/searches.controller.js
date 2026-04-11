import * as searchesService from './searches.service.js';
import { sendSuccess, sendError } from '../../utils/response.utils.js';
import { z } from 'zod';

export async function getRecent(req, res, next) {
  try {
    const searches = await searchesService.getRecentSearches(req.user.id);
    return sendSuccess(res, searches, 'Recent searches fetched');
  } catch (err) {
    next(err);
  }
}

export async function addRecent(req, res, next) {
  try {
    const parsed = z.object({ query: z.string().min(1).max(200).trim() }).safeParse(req.body);
    if (!parsed.success) {
      return sendError(res, 'query is required', 422, 'VALIDATION_ERROR');
    }
    const search = await searchesService.addRecentSearch(req.user.id, parsed.data.query);
    return sendSuccess(res, search, 'Search saved', 201);
  } catch (err) {
    next(err);
  }
}

export async function clearRecent(req, res, next) {
  try {
    const result = await searchesService.clearRecentSearches(req.user.id);
    return sendSuccess(res, result, 'Recent searches cleared');
  } catch (err) {
    next(err);
  }
}
