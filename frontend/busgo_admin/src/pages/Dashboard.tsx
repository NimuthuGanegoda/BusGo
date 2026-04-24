import { useState, useRef, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import {
  Bus, Users, AlertTriangle, ParkingSquare,
  Bell, Calendar, AlertCircle, Settings, UserPlus, UserCheck, X,
  ArrowRight, MapPin, Loader2, Navigation, Search,
} from 'lucide-react';
import { adminApi, busApi, stopsApi } from '../services/api';
import type { DashboardStats, Bus as BusType, Stop } from '../services/api';
import './Dashboard.css';
import busgoLogo from '../assets/busgo-axis-logo.jpeg';

const priorityColors: Record<string, string> = {
  MEDICAL: '#e74c3c', ACCIDENT: '#e67e22',
  CRIMINAL: '#8b5cf6', BREAKDOWN: '#e74c3c',
};
const priorityBg: Record<string, string> = {
  MEDICAL: '#fef2f2', ACCIDENT: '#fef9f0',
  CRIMINAL: '#f5f3ff', BREAKDOWN: '#fef2f2',
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

/* ── Small subtle stop dot marker ── */
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

export default function Dashboard() {
  const navigate = useNavigate();
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifList, setNotifList] = useState<any[]>([]);
  const [realAlerts, setRealAlerts] = useState<any[]>([]);
  const notifRef = useRef<HTMLDivElement>(null);

  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [realBuses, setRealBuses] = useState<BusType[]>([]);
  const [busStops, setBusStops] = useState<Stop[]>([]);
  const [loadingStats, setLoadingStats] = useState(true);
  const [loadingBuses, setLoadingBuses] = useState(true);
  const [stopSearch, setStopSearch] = useState('');

  const unreadCount = notifList.filter((n) => !n.read).length;

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (notifRef.current && !notifRef.current.contains(e.target as Node))
        setShowNotifications(false);
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    adminApi.getDashboard()
      .then((data) => { setStats(data); setLoadingStats(false); })
      .catch(() => setLoadingStats(false));
  }, []);

  useEffect(() => {
    busApi.getNearby(6.9, 79.9, 50)
      .then((data) => { setRealBuses(Array.isArray(data) ? data : []); setLoadingBuses(false); })
      .catch(() => setLoadingBuses(false));
  }, []);

  useEffect(() => {
    stopsApi.getAll()
      .then((data) => setBusStops(Array.isArray(data) ? data : []))
      .catch(console.error);
  }, []);

  useEffect(() => {
    adminApi.listAlerts('status=pending&page_size=10')
      .then((data: any) => {
        const alerts = Array.isArray(data?.alerts) ? data.alerts : (Array.isArray(data) ? data : []);
        setRealAlerts(alerts);
        setNotifList(alerts.map((a: any) => ({
          id: a.id,
          title: `${a.alert_type?.toUpperCase()} Emergency`,
          message: a.description || 'Emergency alert received',
          time: new Date(a.created_at).toLocaleTimeString(),
          type: 'emergency',
          read: false,
        })));
      })
      .catch(console.error);
  }, []);

  const markAllRead = () => setNotifList((p) => p.map((n) => ({ ...n, read: true })));
  const markRead = (id: string) => setNotifList((p) => p.map((n) => (n.id === id ? { ...n, read: true } : n)));
  const dismissNotif = (id: string) => setNotifList((p) => p.filter((n) => n.id !== id));

  const today = new Date().toLocaleDateString('en-LK', {
    year: 'numeric', month: 'long', day: 'numeric'
  });

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

          {/* Bell notification — simple shake animation */}
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
        <div className="stat-card">
          <div className="stat-icon stat-icon-blue"><Bus size={24} /></div>
          <div className="stat-info">
            <div className="stat-value blue">
              {loadingStats ? <Loader2 size={24} className="stat-spinner" /> : stats?.buses.active ?? 0}
            </div>
            <div className="stat-label">Active Buses</div>
            <div className="stat-change blue">{stats ? `${stats.buses.total} total fleet` : ''}</div>
          </div>
        </div>
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

      {/* ── Map + Alerts ── */}
      <div className="dashboard-grid">
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
                url="https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=fsVEp87wcHaGchb3gygh"
                attribution='&copy; OpenStreetMap contributors'
              />
              {/* Only active buses on the map */}
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

              {/* Bus stops — small dot markers */}
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

        <div className="dashboard-card alerts-card">
          <div className="card-header">
            <h2>Emergency Alerts</h2>
            <Link to="/admin/emergencies" className="card-link-btn card-link-btn-red">
              <AlertTriangle size={14} /> View All ({realAlerts.length}) <ArrowRight size={14} />
            </Link>
          </div>
          <div className="alert-list">
            {realAlerts.length === 0 && (
              <div className="alerts-empty"><AlertCircle size={32} /><span>No pending alerts</span></div>
            )}
            {realAlerts.slice(0, 4).map((alert) => {
              const type = alert.alert_type?.toUpperCase() || 'UNKNOWN';
              const color = priorityColors[type] || '#6b7280';
              const bg = priorityBg[type] || '#f9fafb';
              return (
                <div key={alert.id} className="alert-item" style={{ borderLeftColor: color, background: bg }}
                  onClick={() => navigate('/admin/emergencies')}>
                  <div className="alert-item-top">
                    <span className="alert-priority-badge" style={{ background: color }}>
                      {alert.ml_priority_label || 'PENDING'} · {type}
                    </span>
                    <span className={`alert-status-badge ${alert.status}`}>{alert.status}</span>
                  </div>
                  <div className="alert-item-details">
                    {alert.users?.full_name || 'Unknown'} · {alert.description || '—'} · {new Date(alert.created_at).toLocaleTimeString()}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* ── Bus Stops Widget with Search ── */}
      {busStops.length > 0 && (
        <div className="dashboard-card stops-card">
          <div className="card-header">
            <h2>Bus Stops</h2>
            <span className="stops-count">{busStops.length} registered stops</span>
          </div>
          <div className="stops-search-wrap">
            <Search size={16} className="stops-search-icon" />
            <input
              type="text"
              placeholder="Search bus stops..."
              value={stopSearch}
              onChange={(e) => setStopSearch(e.target.value)}
              className="stops-search-input"
            />
            {stopSearch && (
              <button className="stops-search-clear" onClick={() => setStopSearch('')}>
                <X size={14} />
              </button>
            )}
          </div>
          <div className="stops-grid">
            {busStops
              .filter((s) => s.stop_name.toLowerCase().includes(stopSearch.toLowerCase()))
              .map((stop, i, arr) => (
              <div key={stop.id} className="stop-item">
                <div className="stop-item-marker">
                  <div className="stop-item-dot"></div>
                  {i < arr.length - 1 && <div className="stop-item-line"></div>}
                </div>
                <div className="stop-item-info">
                  <div className="stop-item-name">{stop.stop_name}</div>
                  <div className="stop-item-coords">
                    <Navigation size={10} />
                    {stop.latitude.toFixed(4)}, {stop.longitude.toFixed(4)}
                  </div>
                </div>
              </div>
            ))}
            {busStops.filter((s) => s.stop_name.toLowerCase().includes(stopSearch.toLowerCase())).length === 0 && (
              <div className="stops-no-results">No stops found for "{stopSearch}"</div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
