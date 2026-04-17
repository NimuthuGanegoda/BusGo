import { useState, useRef, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import {
  Bus, Users, AlertTriangle, ParkingSquare,
  Bell, Calendar, AlertCircle, Settings, UserPlus, UserCheck, X,
} from 'lucide-react';
import { dashboardStats, activeBuses } from '../data/mockData';
import './Dashboard.css';

const priorityColors: Record<string, string> = {
  MEDICAL: '#e74c3c', ACCIDENT: '#e67e22',
  CRIMINAL: '#8b5cf6', BREAKDOWN: '#e74c3c',
};

const priorityBg: Record<string, string> = {
  MEDICAL: '#fef2f2', ACCIDENT: '#fef9f0',
  CRIMINAL: '#f5f3ff', BREAKDOWN: '#fef2f2',
};

function createBusIcon(passengers: number, capacity: number, status: string) {
  const ratio = passengers / capacity;
  let color = '#4caf50';
  if (status === 'Breakdown') color = '#e74c3c';
  else if (ratio > 0.8) color = '#e74c3c';
  else if (ratio > 0.5) color = '#f59e0b';

  return L.divIcon({
    className: 'custom-bus-marker',
    html: `<div style="background:${color};width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-size:10px;font-weight:700;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,0.3);">${passengers}</div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  });
}

const notifIcons: Record<string, React.ReactNode> = {
  emergency:  <AlertCircle size={16} />,
  system:     <Settings size={16} />,
  driver:     <UserPlus size={16} />,
  passenger:  <UserCheck size={16} />,
};

const notifColors: Record<string, string> = {
  emergency:  '#ef4444',
  system:     '#3b82f6',
  driver:     '#f59e0b',
  passenger:  '#8b5cf6',
};

export default function Dashboard() {
  const navigate = useNavigate();
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifList, setNotifList]  = useState<any[]>([]);
  const [realAlerts, setRealAlerts] = useState<any[]>([]);
  const notifRef = useRef<HTMLDivElement>(null);

  const unreadCount = notifList.filter((n) => !n.read).length;

  // Close notification dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (notifRef.current && !notifRef.current.contains(e.target as Node)) {
        setShowNotifications(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Fetch real emergency alerts from backend
  useEffect(() => {
    const token = localStorage.getItem('busgo_access_token');
    if (!token) return;

    fetch('http://localhost:5000/api/admin/emergency?status=pending&page_size=10', {
      headers: { Authorization: `Bearer ${token}` }
    })
      .then(r => r.json())
      .then(data => {
        const alerts = Array.isArray(data.data) ? data.data : [];
        setRealAlerts(alerts);
        const notifs = alerts.map((a: any) => ({
          id:      a.id,
          title:   `${a.alert_type.toUpperCase()} Emergency`,
          message: a.description || 'Emergency alert received',
          time:    new Date(a.created_at).toLocaleTimeString(),
          type:    'emergency',
          read:    false,
        }));
        setNotifList(notifs);
      })
      .catch(console.error);
  }, []);

  const markAllRead = () => {
    setNotifList((prev) => prev.map((n) => ({ ...n, read: true })));
  };

  const markRead = (id: string) => {
    setNotifList((prev) =>
      prev.map((n) => (n.id === id ? { ...n, read: true } : n))
    );
  };

  const dismissNotif = (id: string) => {
    setNotifList((prev) => prev.filter((n) => n.id !== id));
  };

  const today = new Date().toLocaleDateString('en-LK', {
    year: 'numeric', month: 'long', day: 'numeric'
  });

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <h1>Dashboard</h1>
        <div className="dashboard-header-actions">
          <div className="dashboard-date">
            <Calendar size={16} />
            {today}
          </div>
          <div className="notif-wrapper" ref={notifRef}>
            <button
              className="dashboard-notification-btn"
              onClick={() => setShowNotifications(!showNotifications)}
            >
              <Bell size={20} />
              {unreadCount > 0 && (
                <span className="notification-dot">{unreadCount}</span>
              )}
            </button>

            {showNotifications && (
              <div className="notif-dropdown">
                <div className="notif-dropdown-header">
                  <h3>Notifications</h3>
                  <button className="notif-mark-all" onClick={markAllRead}>
                    Mark all read
                  </button>
                </div>
                <div className="notif-dropdown-list">
                  {notifList.length === 0 && (
                    <div className="notif-empty">No notifications</div>
                  )}
                  {notifList.map((notif) => (
                    <div
                      key={notif.id}
                      className={`notif-item ${notif.read ? 'read' : 'unread'}`}
                      onClick={() => markRead(notif.id)}
                    >
                      <div
                        className="notif-item-icon"
                        style={{
                          color: notifColors[notif.type],
                          background: `${notifColors[notif.type]}15`,
                        }}
                      >
                        {notifIcons[notif.type]}
                      </div>
                      <div className="notif-item-content">
                        <div className="notif-item-title">{notif.title}</div>
                        <div className="notif-item-msg">{notif.message}</div>
                        <div className="notif-item-time">{notif.time}</div>
                      </div>
                      <button
                        className="notif-dismiss"
                        onClick={(e) => {
                          e.stopPropagation();
                          dismissNotif(notif.id);
                        }}
                      >
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

      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon stat-icon-blue"><Bus size={24} /></div>
          <div className="stat-info">
            <div className="stat-value blue">{dashboardStats.activeBuses}</div>
            <div className="stat-label">Active Buses</div>
            <div className="stat-change blue">{dashboardStats.activeBusesChange}</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon stat-icon-indigo"><Users size={24} /></div>
          <div className="stat-info">
            <div className="stat-value indigo">{dashboardStats.passengersToday.toLocaleString()}</div>
            <div className="stat-label">Passengers Today</div>
            <div className="stat-change indigo">{dashboardStats.passengersChange}</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon stat-icon-red"><AlertTriangle size={24} /></div>
          <div className="stat-info">
            <div className="stat-value red">{realAlerts.length}</div>
            <div className="stat-label">Pending Alerts</div>
            <div className="stat-change red">
              {realAlerts.length > 0 ? 'Needs attention' : 'All clear'}
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon stat-icon-purple"><ParkingSquare size={24} /></div>
          <div className="stat-info">
            <div className="stat-value purple">{dashboardStats.standbyBuses}</div>
            <div className="stat-label">Standby Buses</div>
            <div className="stat-change gray">{dashboardStats.standbyNote}</div>
          </div>
        </div>
      </div>

      <div className="dashboard-grid">
        <div className="dashboard-card map-card">
          <div className="card-header">
            <h2>Live Fleet Map</h2>
            <Link to="/admin/fleet-map" className="card-link">View Full Map →</Link>
          </div>
          <div className="dashboard-map-container">
            <MapContainer
              center={[6.85, 79.95]}
              zoom={11}
              style={{ height: '100%', width: '100%', borderRadius: '10px' }}
              zoomControl={false}
              scrollWheelZoom={false}
            >
              <TileLayer
                url="https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=fsVEp87wcHaGchb3gygh"
                attribution='&copy; OpenStreetMap contributors'
              />
              {activeBuses.map((bus) => (
                <Marker
                  key={bus.id}
                  position={[bus.lat!, bus.lng!]}
                  icon={createBusIcon(bus.passengers, bus.capacity, bus.status)}
                >
                  <Popup>
                    <strong>{bus.id}</strong><br />
                    Driver: {bus.driver}<br />
                    Route: {bus.route}<br />
                    Passengers: {bus.passengers}/{bus.capacity}
                  </Popup>
                </Marker>
              ))}
            </MapContainer>
            <div className="map-legend">
              <span className="legend-item"><span className="legend-dot green"></span> Low</span>
              <span className="legend-item"><span className="legend-dot yellow"></span> Moderate</span>
              <span className="legend-item"><span className="legend-dot red"></span> High</span>
            </div>
          </div>
        </div>

        <div className="dashboard-card alerts-card">
          <div className="card-header">
            <h2>Emergency Alerts</h2>
            <Link to="/admin/emergencies" className="card-link">
              View All ({realAlerts.length}) →
            </Link>
          </div>
          <div className="alert-list">
            {realAlerts.length === 0 && (
              <div style={{ color: '#6b7280', textAlign: 'center', padding: '24px' }}>
                No pending alerts ✓
              </div>
            )}
            {realAlerts.slice(0, 3).map((alert) => {
              const type = alert.alert_type.toUpperCase();
              const color = priorityColors[type] || '#6b7280';
              const bg    = priorityBg[type]    || '#f9fafb';
              return (
                <div
                  key={alert.id}
                  className="alert-item"
                  style={{ borderLeftColor: color, background: bg }}
                  onClick={() => navigate('/admin/emergencies')}
                >
                  <div className="alert-item-top">
                    <span className="alert-priority-badge" style={{ background: color }}>
                      {alert.ml_priority_label || 'PENDING'} · {type}
                    </span>
                    <span className={`alert-status-badge ${alert.status}`}>
                      {alert.status}
                    </span>
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
    </div>
  );
}