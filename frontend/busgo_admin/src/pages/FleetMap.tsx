import { useState, useEffect, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { RefreshCw, Bus, User } from 'lucide-react';
import { stopsApi } from '../services/api';
import type { Stop } from '../services/api';
import './FleetMap.css';

const API      = 'http://localhost:5000/api/admin';
const MAPTILER_KEY = (import.meta as any).env?.VITE_MAPTILER_KEY ?? 'fsVEp87wcHaGchb3gygh';
const TILE_URL = `https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=${MAPTILER_KEY}`;
const token    = () => localStorage.getItem('busgo_access_token') ?? '';

type BusRecord = {
  id: string;
  bus_number: string;
  driver_name: string;
  status: string;
  crowd_level: string;
  current_lat: number | null;
  current_lng: number | null;
  speed_kmh: number | null;
  last_location_update: string | null;
  bus_routes: {
    route_number: string;
    route_name: string;
    origin: string;
    destination: string;
  } | null;
};

function createBusIcon(status: string, crowd: string) {
  const color = status === 'breakdown' ? '#e74c3c'
    : crowd === 'high'   ? '#e74c3c'
    : crowd === 'medium' ? '#f59e0b'
    : '#4caf50';
  return L.divIcon({
    className: 'custom-bus-marker',
    html: `<div style="background:${color};width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-size:10px;font-weight:700;border:3px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,0.3);">
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="white">
        <path d="M4 16c0 .88.39 1.67 1 2.22V20c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h8v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1.78c.61-.55 1-1.34 1-2.22V6c0-3.5-3.58-4-8-4s-8 .5-8 4v10zm3.5 1c-.83 0-1.5-.67-1.5-1.5S6.67 14 7.5 14s1.5.67 1.5 1.5S8.33 17 7.5 17zm9 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm1.5-6H6V6h12v5z"/>
      </svg>
    </div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
  });
}

function createStopDot() {
  return L.divIcon({
    className: 'fleet-stop-marker',
    html: `<div style="width:10px;height:10px;border-radius:50%;background:#1a1a1a;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.3);"></div>`,
    iconSize: [10, 10],
    iconAnchor: [5, 5],
    popupAnchor: [0, -8],
  });
}

function isRecentlyUpdated(lastUpdate: string | null): boolean {
  if (!lastUpdate) return false;
  const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
  return new Date(lastUpdate) > twoMinutesAgo;
}

export default function FleetMap() {
  const [buses,        setBuses]        = useState<BusRecord[]>([]);
  const [selected,     setSelected]     = useState<BusRecord | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [lastUpdated,  setLastUpdated]  = useState<Date | null>(null);
  const [statusFilter, setStatusFilter] = useState('all');
  const [busStops, setBusStops] = useState<Stop[]>([]);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const fetchBuses = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const res  = await fetch(`${API}/buses?page_size=100`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      const all: BusRecord[] = Array.isArray(json.data) ? json.data : [];
      setBuses(all);
      setLastUpdated(new Date());
    } catch (e) {
      console.error('[FleetMap]', e);
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchBuses();
    pollRef.current = setInterval(() => fetchBuses(true), 10_000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [fetchBuses]);

  /* Fetch bus stops */
  useEffect(() => {
    stopsApi.getAll()
      .then((data) => setBusStops(Array.isArray(data) ? data : []))
      .catch(console.error);
  }, []);

  const filtered = buses.filter(b =>
    statusFilter === 'all' || b.status === statusFilter
  );

  // ── Only show buses that are active AND have recent GPS update ────────────
  const withGps = filtered.filter(b =>
    b.current_lat &&
    b.current_lng &&
    b.status === 'active' &&
    isRecentlyUpdated(b.last_location_update)
  );

  const withoutGps = filtered.filter(b =>
    !b.current_lat || !b.current_lng || !isRecentlyUpdated(b.last_location_update)
  );

  const getCrowdLabel = (b: BusRecord) => {
    if (b.crowd_level === 'high')   return { label: 'High',   color: '#dc2626', bg: '#fef2f2' };
    if (b.crowd_level === 'medium') return { label: 'Medium', color: '#d97706', bg: '#fffbeb' };
    return { label: 'Low', color: '#16a34a', bg: '#f0fdf4' };
  };

  return (
    <div className="fleet-map-page">
      <div className="fleet-map-toolbar">
        <select
          value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)}
          className="map-filter"
        >
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="breakdown">Breakdown</option>
          <option value="inactive">Inactive</option>
        </select>
        <div className="map-toolbar-right">
          {lastUpdated && (
            <span style={{ fontSize: '12px', color: '#9ca3af', marginRight: '8px' }}>
              Updated {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <button className="map-btn" onClick={() => fetchBuses()}>
            <RefreshCw size={16} /> Refresh
          </button>
        </div>
      </div>

      <div className="fleet-map-content">
        <div className="fleet-map-container">
          {loading ? (
            <div style={{
              display: 'flex', alignItems: 'center',
              justifyContent: 'center', height: '100%', color: '#6b7280'
            }}>
              Loading fleet map...
            </div>
          ) : (
            <MapContainer
              center={[6.85, 79.95]}
              zoom={12}
              style={{ height: '100%', width: '100%' }}
              zoomControl={false}
            >
              <TileLayer
                url={TILE_URL}
                attribution='&copy; <a href="https://www.maptiler.com/">MapTiler</a>'
              />
              {withGps.map(bus => (
                <Marker
                  key={bus.id}
                  position={[bus.current_lat!, bus.current_lng!]}
                  icon={createBusIcon(bus.status, bus.crowd_level)}
                  eventHandlers={{ click: () => setSelected(bus) }}
                >
                  <Popup>
                    <strong>{bus.bus_number}</strong><br />
                    {bus.driver_name || '—'}<br />
                    Route {bus.bus_routes?.route_number || 'N/A'}<br />
                    Speed: {bus.speed_kmh?.toFixed(0) || '0'} km/h
                  </Popup>
                </Marker>
              ))}

              {/* Bus stops — black dot markers */}
              {busStops.map(stop => (
                <Marker
                  key={`stop-${stop.id}`}
                  position={[stop.latitude, stop.longitude]}
                  icon={createStopDot()}
                >
                  <Popup><strong>{stop.stop_name}</strong></Popup>
                </Marker>
              ))}
            </MapContainer>
          )}

          <div className="map-crowd-legend">
            <span className="legend-title">CROWD LEVEL</span>
            <span className="legend-item">
              <span className="legend-dot green"></span> Low
            </span>
            <span className="legend-item">
              <span className="legend-dot yellow"></span> Medium
            </span>
            <span className="legend-item">
              <span className="legend-dot red"></span> High
            </span>
            <span className="legend-item">
              <span className="legend-dot black"></span> Stop
            </span>
          </div>

          {/* Live bus count badge */}
          <div style={{
            position: 'absolute', top: '12px', right: '12px',
            background: withGps.length > 0 ? '#16a34a' : '#6b7280',
            color: 'white', padding: '6px 12px',
            borderRadius: '8px', fontSize: '12px', fontWeight: 700,
            boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          }}>
            {withGps.length} BUS{withGps.length !== 1 ? 'ES' : ''} LIVE
          </div>

          {withoutGps.length > 0 && (
            <div style={{
              position: 'absolute', bottom: '60px', left: '12px',
              background: 'white', padding: '8px 12px',
              borderRadius: '8px', fontSize: '12px', color: '#6b7280',
              boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
            }}>
              ⚠ {withoutGps.length} bus{withoutGps.length > 1 ? 'es' : ''} offline
            </div>
          )}
        </div>

        {/* Side panel */}
        <div className="bus-detail-panel">
          {selected ? (
            <>
              <div className="bus-detail-header">
                <h2>{selected.bus_number} — Selected</h2>
                <p>
                  Route {selected.bus_routes?.route_number || 'N/A'} ·{' '}
                  {selected.bus_routes?.route_name || '—'}
                </p>
              </div>
              <div className="bus-detail-rows">
                {[
                  ['BUS NUMBER', selected.bus_number],
                  ['DRIVER',     selected.driver_name || '—'],
                  ['ROUTE',      selected.bus_routes
                    ? `${selected.bus_routes.route_number} — ${selected.bus_routes.origin} → ${selected.bus_routes.destination}`
                    : 'Unassigned'],
                  ['SPEED',      selected.speed_kmh
                    ? `${selected.speed_kmh.toFixed(0)} km/h`
                    : 'No GPS'],
                  ['STATUS',     selected.status],
                  ['GPS AGE',    selected.last_location_update
                    ? isRecentlyUpdated(selected.last_location_update)
                      ? '✅ Live'
                      : '⚠️ Stale'
                    : 'Never'],
                  ['LAST GPS',   selected.last_location_update
                    ? new Date(selected.last_location_update).toLocaleTimeString()
                    : 'Never'],
                ].map(([label, value]) => (
                  <div key={label} className="detail-row">
                    <span className="detail-label">{label}</span>
                    <span className="detail-value">{value}</span>
                  </div>
                ))}
                <div className="detail-row">
                  <span className="detail-label">CROWD</span>
                  <span style={{
                    ...(() => {
                      const c = getCrowdLabel(selected);
                      return { color: c.color, background: c.bg };
                    })(),
                    padding: '2px 8px', borderRadius: '6px',
                    fontSize: '12px', fontWeight: 600,
                  }}>
                    {getCrowdLabel(selected).label}
                  </span>
                </div>
              </div>
              <div className="bus-detail-actions">
                <button
                  className="detail-action-btn secondary"
                  onClick={() => setSelected(null)}
                >
                  <User size={16} /> Deselect
                </button>
              </div>
            </>
          ) : (
            <div style={{
              padding: '24px', textAlign: 'center', color: '#9ca3af'
            }}>
              <Bus size={32} style={{
                margin: '0 auto 12px', display: 'block', opacity: 0.3
              }} />
              <p style={{ fontSize: '14px' }}>
                Click a bus on the map to see its details
              </p>
              <p style={{ fontSize: '12px', marginTop: '8px' }}>
                {withGps.length} buses with live GPS · {withoutGps.length} offline
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
