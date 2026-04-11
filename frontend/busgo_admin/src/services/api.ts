/**
 * api.ts — Centralised API client for BUSGO Axis (Admin Web)
 * All requests go through here so token management is in one place.
 */

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000/api';

// ── Token Storage ──────────────────────────────────────────────────────────────
export const TokenStore = {
  getAccess:   () => localStorage.getItem('busgo_access_token'),
  getRefresh:  () => localStorage.getItem('busgo_refresh_token'),
  set: (access: string, refresh: string) => {
    localStorage.setItem('busgo_access_token', access);
    localStorage.setItem('busgo_refresh_token', refresh);
  },
  clear: () => {
    localStorage.removeItem('busgo_access_token');
    localStorage.removeItem('busgo_refresh_token');
  },
};

// ── Core fetch wrapper ─────────────────────────────────────────────────────────
async function request<T>(
  path: string,
  options: RequestInit = {},
  retried = false
): Promise<T> {
  const token = TokenStore.getAccess();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const res = await fetch(`${BASE_URL}${path}`, { ...options, headers });

  // Auto-refresh on 401 TOKEN_EXPIRED
  if (res.status === 401 && !retried) {
    const body = await res.json().catch(() => ({}));
    if (body.code === 'TOKEN_EXPIRED') {
      const refreshed = await tryRefresh();
      if (refreshed) return request<T>(path, options, true);
    }
    TokenStore.clear();
    window.location.href = '/admin/login';
    throw new Error('Session expired');
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: 'Request failed' }));
    throw new Error(err.message || `HTTP ${res.status}`);
  }

  const data = await res.json();
  return data.data as T;
}

async function tryRefresh(): Promise<boolean> {
  const refresh_token = TokenStore.getRefresh();
  if (!refresh_token) return false;
  try {
    const res = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token }),
    });
    if (!res.ok) return false;
    const body = await res.json();
    TokenStore.set(body.data.access_token, body.data.refresh_token);
    return true;
  } catch {
    return false;
  }
}

// ── Convenience methods ────────────────────────────────────────────────────────
export const api = {
  get:    <T>(path: string)                    => request<T>(path, { method: 'GET' }),
  post:   <T>(path: string, body: unknown)     => request<T>(path, { method: 'POST',   body: JSON.stringify(body) }),
  patch:  <T>(path: string, body: unknown)     => request<T>(path, { method: 'PATCH',  body: JSON.stringify(body) }),
  put:    <T>(path: string, body: unknown)     => request<T>(path, { method: 'PUT',    body: JSON.stringify(body) }),
  delete: <T>(path: string)                    => request<T>(path, { method: 'DELETE' }),
};

// ── Auth ───────────────────────────────────────────────────────────────────────
export const authApi = {
  login: (email: string, password: string) =>
    api.post<{ user: User; access_token: string; refresh_token: string }>(
      '/auth/login', { email, password }
    ),
  logout: (refresh_token: string) =>
    api.post('/auth/logout', { refresh_token }),
};

// ── Admin Dashboard ────────────────────────────────────────────────────────────
export const adminApi = {
  getDashboard: () => api.get<DashboardStats>('/admin/dashboard'),

  // Users
  listUsers:     (params: string) => api.get<PaginatedResponse<User>>(`/admin/users?${params}`),
  getUser:       (id: string)     => api.get<User>(`/admin/users/${id}`),
  updateUser:    (id: string, body: Partial<User>) => api.patch<User>(`/admin/users/${id}`, body),
  deactivate:    (id: string)     => api.patch<User>(`/admin/users/${id}/deactivate`, {}),
  reactivate:    (id: string)     => api.patch<User>(`/admin/users/${id}/reactivate`, {}),

  // Buses
  listBuses:     (params: string) => api.get<PaginatedResponse<Bus>>(`/admin/buses?${params}`),
  createBus:     (body: Partial<Bus>) => api.post<Bus>('/admin/buses', body),
  updateBus:     (id: string, body: Partial<Bus>) => api.patch<Bus>(`/admin/buses/${id}`, body),
  deleteBus:     (id: string)     => api.delete(`/admin/buses/${id}`),

  // Emergency
  listAlerts:    (params: string) => api.get<PaginatedResponse<Alert>>(`/admin/emergency?${params}`),
  updateAlertStatus: (id: string, status: string) =>
    api.patch<Alert>(`/admin/emergency/${id}/status`, { status }),

  // Fleet
  getStandby:    ()               => api.get<Bus[]>('/admin/fleet/standby'),
  deployBus:     (id: string, route_id: string) =>
    api.patch<Bus>(`/admin/fleet/${id}/deploy`, { route_id }),
  recallBus:     (id: string)     => api.patch<Bus>(`/admin/fleet/${id}/recall`, {}),

  // Audit logs
  getAuditLogs:  (params: string) => api.get<PaginatedResponse<AuditLog>>(`/admin/audit-logs?${params}`),

  // Routes
  listRoutes:    ()               => api.get<Route[]>('/routes'),
  createRoute:   (body: Partial<Route>) => api.post<Route>('/admin/routes', body),
  updateRoute:   (id: string, body: Partial<Route>) => api.patch<Route>(`/admin/routes/${id}`, body),
  deleteRoute:   (id: string)     => api.delete(`/admin/routes/${id}`),
};

// ── Live bus locations (public endpoint) ───────────────────────────────────────
export const busApi = {
  getNearby: (lat: number, lng: number, radius = 20) =>
    api.get<Bus[]>(`/buses/nearby?lat=${lat}&lng=${lng}&radius=${radius}`),
};

// ── Types ──────────────────────────────────────────────────────────────────────
export interface User {
  id: string;
  email: string;
  full_name: string;
  username?: string;
  phone?: string;
  role: 'passenger' | 'driver' | 'admin';
  membership_type: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Bus {
  id: string;
  bus_number: string;
  driver_name: string;
  driver_phone?: string;
  driver_user_id?: string;
  route_id: string;
  current_lat?: number;
  current_lng?: number;
  heading?: number;
  speed_kmh?: number;
  crowd_level: 'low' | 'medium' | 'high' | 'full';
  status: 'active' | 'inactive' | 'breakdown';
  last_location_update?: string;
  bus_routes?: Route;
}

export interface Alert {
  id: string;
  alert_type: string;
  description?: string;
  latitude?: number;
  longitude?: number;
  status: 'pending' | 'acknowledged' | 'resolved';
  ml_priority?: number;
  ml_priority_label?: string;
  ml_is_false?: boolean;
  ml_confidence?: number;
  ml_action?: string;
  created_at: string;
  updated_at: string;
  users?: { full_name: string; email: string; phone?: string };
  buses?: { bus_number: string; driver_name: string };
}

export interface Route {
  id: string;
  route_number: string;
  route_name: string;
  origin: string;
  destination: string;
  color: string;
  is_active: boolean;
}

export interface AuditLog {
  id: string;
  action: string;
  table_name: string;
  record_id?: string;
  metadata: Record<string, unknown>;
  created_at: string;
  users?: { full_name: string; email: string };
}

export interface DashboardStats {
  users:  { total: number; active_passengers: number };
  buses:  { total: number; active: number; inactive: number };
  alerts: { pending: number; critical_pending: number };
  trips:  { ongoing: number; today: number };
}

export interface PaginatedResponse<T> {
  items: T[];
  pagination: {
    total: number; page: number; pageSize: number;
    totalPages: number; hasNext: boolean; hasPrev: boolean;
  };
}
