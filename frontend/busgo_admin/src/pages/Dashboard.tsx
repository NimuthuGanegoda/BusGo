import { useState, useRef, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import {
  Bus, Users, AlertTriangle, ParkingSquare,
  Bell, Calendar, AlertCircle, Settings, UserPlus, UserCheck, X,
  ArrowRight, MapPin, Loader2, Navigation, Search, Activity,
  Clock, RefreshCw,
} from 'lucide-react';
import { adminApi, busApi, stopsApi } from '../services/api';
import type { DashboardStats, Bus as BusType, Stop } from '../services/api';
import './Dashboard.css';
import busgoLogo from '../assets/busgo-axis-logo.jpeg';

const priorityColors: Record<string, string> = {
  MEDICAL: '#e74c3c', ACCIDENT: '#e67e22',
  CRIMINAL: '#8b5cf6', BREAKDOWN: '#e74c3c',
};

function createBusIcon(crowdLevel: string, status: string) {
  let color = '#22c55e';
  let label = 'L';
  if (status === 'breakdown') { color = '#e74c3c'; label = '!'; }
  else if (crowdLevel === 'full')   { color = '#dc2626'; label = 'F'; }
  else if (crowdLevel === 'high')   { color = '#e74c3c'; label = 'H'; }
  else if (crowdLevel === 'medium') { color = '#f59e0b'; label = 'M'; }

  return L.divIcon({
    className: 'custom-bus-marker',
    html: `<div style="background:${color};width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-size:10px;font-weight:700;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,0.3);">${label}</div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  });
}

function createStopDot() {
  return L.divIcon({
    className: 'stop-dot-marker',
    html: `<div class="stop-dot"><div class="stop-dot-inner"></div></div>`,
    iconSize: [12, 12],
    iconAnchor: [6, 6],
    popupAnchor: [0, -8],
  });
}

const notifIcons: Record<string, React.ReactNode> = {
  emergency: <AlertCircle size={16} />, system: <Settings size={16} />,
  driver: <UserPlus size={16} />, passenger: <UserCheck size={16} />,
};
const notifColors: Record<string, string> = {
  emergency: '#ef4444', system: '#3b82f6', driver: '#f59e0b', passenger: '#8b5cf6',
};

const CROWD_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  low:    { label: 'Low',    color: '#16a34a', bg: '#f0fdf4' },
  medium: { label: 'Medium', color: '#d97706', bg: '#fffbeb' },
  high:   { label: 'High',   color: '#dc2626', bg: '#fef2f2' },
  full:   { label: 'Full',   color: '#7c3aed', bg: '#f5f3ff' },
};

function timeSince(dateStr: string | null): string {
  if (!dateStr) return 'No GPS';
  const diff = Math.floor((Date.now() - new Date(dateStr).getTime()) / 1000);
  if (diff < 60)   return `${diff}s ago`;
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  return `${Math.floor(diff / 3600)}h ago`;
}

export default function Dashboard() {
  const navigate = useNavigate();
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifList, setNotifList]   = useState<any[]>([]);
  const notifRef = useRef<HTMLDivElement>(null);

  const [stats,        setStats]        = useState<DashboardStats | null>(null);
  const [realBuses,    setRealBuses]    = useState<BusType[]>([]);
  const [busStops,     setBusStops]     = useState<Stop[]>([]);
  const [loadingStats, setLoadingStats] = useState(true);
  const [loadingBuses, setLoadingBuses] = useState(true);
  const [lastRefresh,  setLastRefresh]  = useState<Date | null>(null);

  const unreadCount = notifList.filter((n) => !n.read).length;

  // ── Click-outside for notification panel ────────────────────────────────
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (notifRef.current && !notifRef.current.contains(e.target as Node))
        setShowNotifications(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // ── Core data fetchers ────────────────────────────────────────────────────
  const fetchStats = useCallback(async () => {
    try {
      const data = await adminApi.getDashboard();
      setStats(data);
    } catch (_) {}
    finally { setLoadingStats(false); }
  }, []);

  const fetchBuses = useCallback(async () => {
    try {
      const data = await busApi.getNearby(6.9, 79.9, 50);
      setRealBuses(Array.isArray(data) ? data : []);
    } catch (_) {}
    finally { setLoadingBuses(false); }
  }, []);

  const fetchAlerts = useCallback(async () => {
    try {
      const data: any = await adminApi.listAlerts('status=pending&page_size=10');
      const alerts = Array.isArray(data?.alerts) ? data.alerts : (Array.isArray(data) ? data : []);
      setNotifList(alerts.map((a: any) => ({
        id: a.id,
        title: `${a.alert_type?.toUpperCase()} Emergency`,
        message: a.description || 'Emergency alert received',
        time: new Date(a.created_at).toLocaleTimeString(),
        type: 'emergency',
        read: false,
      })));
    } catch (_) {}
  }, []);

  // ── Initial load + bus stops (static — no need to poll) ──────────────────
  useEffect(() => {
    fetchStats();
    fetchBuses();
    fetchAlerts();
    stopsApi.getAll()
      .then((data) => setBusStops(Array.isArray(data) ? data : []))
      .catch(() => {});
  }, [fetchStats, fetchBuses, fetchAlerts]);

  // ── Auto-refresh every 30 seconds ─────────────────────────────────────────
  useEffect(() => {
    const id = setInterval(() => {
      fetchStats();
      fetchBuses();
      fetchAlerts();
      setLastRefresh(new Date());
    }, 30_000);
    return () => clearInterval(id);
  }, [fetchStats, fetchBuses, fetchAlerts]);

  const markAllRead  = () => setNotifList((p) => p.map((n) => ({ ...n, read: true })));
  const markRead     = (id: string) => setNotifList((p) => p.map((n) => (n.id === id ? { ...n, read: true } : n)));
  const dismissNotif = (id: string) => setNotifList((p) => p.filter((n) => n.id !== id));

  const today = new Date().toLocaleDateString('en-LK', {
    year: 'numeric', month: 'long', day: 'numeric'
  });

  // Active buses for the driver status panel
  const activeBuses = realBuses.filter(b => b.status === 'active');

  return (
    <div className="dashboard">
      {/* ── Header ── */}
      <div className="dashboard-header">
        <h1>Dashboard</h1>
        <div className="dashboard-header-actions">
          <div className="dashboard-date">
            <Calendar size={16} />
            {today}
          </div>

          {lastRefresh && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: '#9ca3af' }}>
              <RefreshCw size={12} />
              {lastRefresh.toLocaleTimeString()}
            </div>
          )}

          {/* Bell notification */}
          <div className="notif-wrapper" ref={notifRef}>
            <button
              className="dashboard-notification-btn"
              onClick={() => setShowNotifications(!showNotifications)}
            >
              <span className={`bell-icon ${unreadCount > 0 ? 'bell-ringing' : ''}`}>
                <Bell size={20} />
              </span>
              {unreadCount > 0 && (
                <span className="notification-dot">{unreadCount}</span>
              )}
            </button>

            {showNotifications && (
              <div className="notif-dropdown">
                <div className="notif-dropdown-header">
                  <h3>Notifications</h3>
                  <button className="notif-mark-all" onClick={markAllRead}>Mark all read</button>
                </div>
                <div className="notif-dropdown-list">
                  {notifList.length === 0 && <div className="notif-empty">No notifications</div>}
                  {notifList.map((notif) => (
                    <div key={notif.id} className={`notif-item ${notif.read ? 'read' : 'unread'}`}
                      onClick={() => markRead(notif.id)}>
                      <div className="notif-item-icon"
                        style={{ color: notifColors[notif.type], background: `${notifColors[notif.type]}15` }}>
                        {notifIcons[notif.type]}
                      </div>
                      <div className="notif-item-content">
                        <div className="notif-item-title">{notif.title}</div>
                        <div className="notif-item-msg">{notif.message}</div>
                        <div className="notif-item-time">{notif.time}</div>
                      </div>
                      <button className="notif-dismiss"
                        onClick={(e) => { e.stopPropagation(); dismissNotif(notif.id); }}>
                        <X size={14} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Stats ── */}
      <div className="stats-grid">
        {/* Active Buses — X / Y format */}
        <div className="stat-card">
          <div className="stat-icon stat-icon-blue"><Bus size={24} /></div>
          <div className="stat-info">
            <div className="stat-value blue" style={{ fontSize: '26px' }}>
              {loadingStats
                ? <Loader2 size={24} className="stat-spinner" />
                : <>{stats?.buses.active ?? 0}<span style={{ color: '#9ca3af', fontWeight: 400, fontSize: '20px' }}> / {stats?.buses.total ?? 0}</span></>
              }
            </div>
            <div className="stat-label">Active Buses</div>
            <div className="stat-change gray">Total registered fleet</div>
          </div>
        </div>

        {/* Trips Today */}
        <div className="stat-card">
          <div className="stat-icon stat-icon-indigo"><Users size={24} /></div>
          <div className="stat-info">
            <div className="stat-value indigo">
              {loadingStats ? <Loader2 size={24} className="stat-spinner" /> : stats?.trips.today ?? 0}
            </div>
            <div className="stat-label">Trips Today</div>
            <div className="stat-change indigo">{stats ? `${stats.trips.ongoing} ongoing` : ''}</div>
          </div>
        </div>

        {/* Pending Alerts */}
        <div className="stat-card">
          <div className="stat-icon stat-icon-red"><AlertTriangle size={24} /></div>
          <div className="stat-info">
            <div className="stat-value red">
              {loadingStats ? <Loader2 size={24} className="stat-spinner" /> : stats?.alerts.pending ?? 0}
            </div>
            <div className="stat-label">Pending Alerts</div>
            <div className="stat-change red">
              {stats ? (stats.alerts.critical_pending > 0 ? `${stats.alerts.critical_pending} critical` : 'All clear') : ''}
            </div>
          </div>
        </div>

        {/* Standby Buses */}
        <div className="stat-card">
          <div className="stat-icon stat-icon-purple"><ParkingSquare size={24} /></div>
          <div className="stat-info">
            <div className="stat-value purple">
              {loadingStats ? <Loader2 size={24} className="stat-spinner" /> : stats?.buses.inactive ?? 0}
            </div>
            <div className="stat-label">Standby Buses</div>
            <div className="stat-change gray">Ready to deploy</div>
          </div>
        </div>
      </div>

      {/* ── Map + Active Driver Status ── */}
      <div className="dashboard-grid">
        {/* Mini Fleet Map */}
        <div className="dashboard-card map-card">
          <div className="card-header">
            <h2>Live Fleet Map</h2>
            <Link to="/admin/fleet-map" className="card-link-btn">
              <MapPin size={14} /> View Full Map <ArrowRight size={14} />
            </Link>
          </div>
          <div className="dashboard-map-container">
            <MapContainer center={[6.85, 79.95]} zoom={11}
              style={{ height: '100%', width: '100%', borderRadius: '10px' }}
              zoomControl={false} scrollWheelZoom={false}>
              <TileLayer
                url={`https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${import.meta.env.VITE_MAPTILER_KEY ?? ''}`}
                attribution='&copy; OpenStreetMap contributors'
              />
              {realBuses.filter(b => b.current_lat && b.current_lng).map((bus) => (
                <Marker key={bus.id} position={[bus.current_lat!, bus.current_lng!]}
                  icon={createBusIcon(bus.crowd_level, bus.status)}>
                  <Popup>
                    <strong>{bus.bus_number}</strong><br />
                    Driver: {bus.driver_name}<br />
                    Route: {bus.bus_routes?.route_name || '—'}<br />
                    Crowd: {bus.crowd_level}
                  </Popup>
                </Marker>
              ))}
              {busStops.map((stop) => (
                <Marker key={`stop-${stop.id}`} position={[stop.latitude, stop.longitude]}
                  icon={createStopDot()}>
                  <Popup><strong>{stop.stop_name}</strong></Popup>
                </Marker>
              ))}
            </MapContainer>
            <div className="map-legend">
              <span className="legend-item"><span className="legend-dot green"></span> Low</span>
              <span className="legend-item"><span className="legend-dot yellow"></span> Moderate</span>
              <span className="legend-item"><span className="legend-dot red"></span> High</span>
              <span className="legend-item"><span className="legend-dot teal"></span> Stop</span>
            </div>
            {loadingBuses && (
              <div className="map-loading"><Loader2 size={20} className="stat-spinner" /> Loading...</div>
            )}
          </div>
        </div>

        {/* Active Driver Status — replaces Emergency Alerts */}
        <div className="dashboard-card">
          <div className="card-header">
            <h2>
              <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Activity size={18} color="#16a34a" />
                Active Driver Status
              </span>
            </h2>
            <Link to="/admin/fleet" className="card-link-btn">
              <Bus size={14} /> Fleet Management <ArrowRight size={14} />
            </Link>
          </div>

          <div className="driver-status-list">
            {loadingBuses ? (
              <div style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>
                <Loader2 size={24} className="stat-spinner" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '13px' }}>Loading drivers...</div>
              </div>
            ) : activeBuses.length === 0 ? (
              <div className="driver-status-empty">
                <Bus size={32} />
                <span>No buses currently active</span>
                <p style={{ fontSize: '12px', color: '#9ca3af', marginTop: '4px' }}>
                  Drivers will appear here when they start their route
                </p>
              </div>
            ) : (
              activeBuses.slice(0, 5).map((bus) => {
                const crowd = CROWD_CONFIG[bus.crowd_level] || CROWD_CONFIG.low;
                const hasGps = !!bus.current_lat && !!bus.current_lng;
                return (
                  <div key={bus.id} className="driver-status-item">
                    {/* Bus number badge */}
                    <div className="driver-bus-badge">
                      <Bus size={14} />
                      <span>{bus.bus_number}</span>
                    </div>

                    {/* Driver info */}
                    <div className="driver-status-content">
                      <div className="driver-status-top">
                        <span className="driver-name">{bus.driver_name || '—'}</span>
                        <span className="driver-crowd-badge"
                          style={{ color: crowd.color, background: crowd.bg }}>
                          {crowd.label}
                        </span>
                      </div>
                      <div className="driver-status-meta">
                        <span>
                          <Navigation size={10} />
                          {bus.bus_routes?.route_name || 'No route assigned'}
                        </span>
                        <span style={{ color: hasGps ? '#16a34a' : '#9ca3af' }}>
                          <Clock size={10} />
                          {timeSince(bus.last_location_update)}
                        </span>
                        {bus.speed_kmh != null && bus.speed_kmh > 0 && (
                          <span>{bus.speed_kmh} km/h</span>
                        )}
                      </div>
                    </div>

                    {/* GPS indicator */}
                    <div className="driver-gps-dot" title={hasGps ? 'GPS active' : 'No GPS signal'}>
                      <span style={{
                        width: '8px', height: '8px', borderRadius: '50%',
                        background: hasGps ? '#16a34a' : '#d1d5db',
                        display: 'block',
                        boxShadow: hasGps ? '0 0 0 3px rgba(22,163,74,0.2)' : 'none',
                      }} />
                    </div>
                  </div>
                );
              })
            )}

            {activeBuses.length > 5 && (
              <div style={{ textAlign: 'center', paddingTop: '12px', borderTop: '1px solid #f0f2f5' }}>
                <Link to="/admin/fleet" style={{ fontSize: '13px', color: '#1a8a7a', fontWeight: 600, textDecoration: 'none' }}>
                  +{activeBuses.length - 5} more active buses → Fleet Management
                </Link>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
