import { useState, useEffect, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet';
import L from 'leaflet';
import { RefreshCw, Bus, User, Map as MapIcon } from 'lucide-react';
import { stopsApi, adminApi } from '../services/api';
import type { Stop, Route } from '../services/api';
import './FleetMap.css';

const API          = 'https://busgo-production.up.railway.app/api/admin';
const MAPTILER_KEY = import.meta.env.VITE_MAPTILER_KEY ?? '';
const TILE_URL     = `https://api.maptiler.com/maps/streets-v2-dark/{z}/{x}/{y}.png?key=${MAPTILER_KEY}`;
const token        = () => localStorage.getItem('busgo_access_token') ?? '';

// â”€â”€ Types â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
  avg_rating:    number | null;
  total_reviews: number;
};

// â”€â”€ Fit map to all content â€” re-fires when trigger value changes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function FitBoundsOnce({ positions, trigger }: { positions: [number, number][]; trigger: number }) {
  const map    = useMap();
  const fitted = useRef(-1);
  useEffect(() => {
    if (fitted.current !== trigger && positions.length > 0) {
      fitted.current = trigger;
      map.fitBounds(L.latLngBounds(positions), { padding: [50, 50] });
    }
  }, [map, positions, trigger]);
  return null;
}

// â”€â”€ Bus icon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function createBusIcon(status: string, crowd: string) {
  const color =
    status === 'breakdown' ? '#e74c3c'
    : crowd === 'high'     ? '#e74c3c'
    : crowd === 'medium'   ? '#f59e0b'
    :                        '#4caf50';
  return L.divIcon({
    className: 'custom-bus-marker',
    html: `<div style="background:${color};width:32px;height:32px;border-radius:50%;
      display:flex;align-items:center;justify-content:center;
      border:3px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,0.4);">
      <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="white">
        <path d="M4 16c0 .88.39 1.67 1 2.22V20c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h8v1
          c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1.78c.61-.55 1-1.34 1-2.22V6c0-3.5-3.58-4-8-4
          s-8 .5-8 4v10zm3.5 1c-.83 0-1.5-.67-1.5-1.5S6.67 14 7.5 14s1.5.67 1.5 1.5
          S8.33 17 7.5 17zm9 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5
          -.67 1.5-1.5 1.5zm1.5-6H6V6h12v5z"/>
      </svg>
    </div>`,
    iconSize: [32, 32], iconAnchor: [16, 16],
  });
}

// â”€â”€ Stop dot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
function createStopDot() {
  return L.divIcon({
    className:   'fleet-stop-marker',
    html:        `<div style="width:10px;height:10px;border-radius:50%;
      background:#fff;border:2px solid #555;
      box-shadow:0 1px 4px rgba(0,0,0,0.4);"></div>`,
    iconSize:    [10, 10],
    iconAnchor:  [5, 5],
    popupAnchor: [0, -8],
  });
}

function isRecentlyUpdated(lastUpdate: string | null): boolean {
  if (!lastUpdate) return false;
  return new Date(lastUpdate) > new Date(Date.now() - 2 * 60 * 1000);
}

// â”€â”€ Component â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
export default function FleetMap() {
  const [buses,        setBuses]        = useState<BusRecord[]>([]);
  const [selected,     setSelected]     = useState<BusRecord | null>(null);
  const [loading,      setLoading]      = useState(true);
  const [lastUpdated,  setLastUpdated]  = useState<Date | null>(null);
  const [statusFilter, setStatusFilter] = useState('all');
  const [busStops,     setBusStops]     = useState<Stop[]>([]);
  const [routes,       setRoutes]       = useState<Route[]>([]);
  const [routesLoaded, setRoutesLoaded] = useState(false);
  const [showRoutes,   setShowRoutes]   = useState(true);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // â”€â”€ Buses (poll every 10s) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const fetchBuses = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const res  = await fetch(`${API}/buses?page_size=100`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      setBuses(Array.isArray(json.data) ? json.data : []);
      setLastUpdated(new Date());
    } catch (e) {
      console.error('[FleetMap] buses:', e);
    } finally {
      if (!silent) setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchBuses();
    pollRef.current = setInterval(() => fetchBuses(true), 10_000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [fetchBuses]);

  // â”€â”€ Stops â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  useEffect(() => {
    stopsApi.getAll()
      .then(data => setBusStops(Array.isArray(data) ? data : []))
      .catch(e => console.error('[FleetMap] stops:', e));
  }, []);

  // â”€â”€ Routes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  useEffect(() => {
    adminApi.listRoutes()
      .then(data => {
        const list = Array.isArray(data) ? data : [];
        console.log(`[FleetMap] routes loaded: ${list.length}`);
        console.log('[FleetMap] sample waypoints:', list[0]?.waypoints);
        setRoutes(list);
        setRoutesLoaded(true);
      })
      .catch(e => console.error('[FleetMap] routes:', e));
  }, []);

  // â”€â”€ Derived â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  const filtered    = buses.filter(b => statusFilter === 'all' || b.status === statusFilter);
  const withGps     = filtered.filter(b =>
    b.current_lat && b.current_lng && b.status === 'active' &&
    isRecentlyUpdated(b.last_location_update)
  );
  const withoutGps  = filtered.filter(b =>
    !b.current_lat || !b.current_lng || !isRecentlyUpdated(b.last_location_update)
  );

  // Positions for fitBounds â€” route waypoints only (they span the whole island)
  const allPositions: [number, number][] = routes.flatMap(r =>
    (r.waypoints ?? []).map(wp => [wp.lat, wp.lng] as [number, number])
  );

  // Only routes that have at least 2 waypoints with actual numbers
  const drawableRoutes = routes.filter(r => {
    const wps = r.waypoints ?? [];
    return wps.length >= 2 && wps.every(wp => typeof wp.lat === 'number' && typeof wp.lng === 'number');
  });

  const getCrowdLabel = (b: BusRecord) => {
    if (b.crowd_level === 'high')   return { label: 'High',   color: '#dc2626', bg: '#fef2f2' };
    if (b.crowd_level === 'medium') return { label: 'Medium', color: '#d97706', bg: '#fffbeb' };
    return { label: 'Low', color: '#16a34a', bg: '#f0fdf4' };
  };

  // â”€â”€ Render â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  return (
    <div className="fleet-map-page">

      {/* Toolbar */}
      <div className="fleet-map-toolbar">
        <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="map-filter">
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="breakdown">Breakdown</option>
          <option value="inactive">Inactive</option>
        </select>

        <button
          className={`map-btn ${showRoutes ? 'primary' : ''}`}
          onClick={() => setShowRoutes(v => !v)}
        >
          <MapIcon size={16} />
          {showRoutes ? 'Hide Routes' : 'Show Routes'}
        </button>

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

      {/* Map + panel */}
      <div className="fleet-map-content">
        <div className="fleet-map-container">
          {loading ? (
            <div style={{ display:'flex', alignItems:'center', justifyContent:'center', height:'100%', color:'#6b7280' }}>
              Loading fleet map...
            </div>
          ) : (
            <MapContainer
              center={[7.8731, 80.7718]}
              zoom={8}
              style={{ height: '100%', width: '100%' }}
              zoomControl={false}
              attributionControl={false}
            >
              <TileLayer url={TILE_URL} />

              {/* Auto-fit to routes once they load */}
              {routesLoaded && allPositions.length > 0 && (
                <FitBoundsOnce positions={allPositions} trigger={routes.length} />
              )}

              {/* â”€â”€ Route lines â”€â”€ */}
              {showRoutes && drawableRoutes.map(route => {
                const positions = (route.waypoints ?? []).map(
                  wp => [wp.lat, wp.lng] as [number, number]
                );
                return (
                  <Polyline
                    key={`route-${route.id}`}
                    positions={positions}
                    pathOptions={{
                      color:   route.color || '#00D4FF',
                      weight:  5,
                      opacity: 0.9,
                    }}
                  >
                    <Popup>
                      <strong>Route {route.route_number}</strong><br />
                      {route.route_name}<br />
                      {route.origin} â†’ {route.destination}
                    </Popup>
                  </Polyline>
                );
              })}

              {/* â”€â”€ Bus markers â”€â”€ */}
              {withGps.map(bus => (
                <Marker
                  key={bus.id}
                  position={[bus.current_lat!, bus.current_lng!]}
                  icon={createBusIcon(bus.status, bus.crowd_level)}
                  eventHandlers={{ click: () => setSelected(bus) }}
                >
                  <Popup>
                    <strong>{bus.bus_number}</strong><br />
                    {bus.driver_name || 'â€“'}<br />
                    Route {bus.bus_routes?.route_number || 'N/A'}<br />
                    Speed: {bus.speed_kmh?.toFixed(0) || '0'} km/h
                  </Popup>
                </Marker>
              ))}

              {/* â”€â”€ Stop dots â”€â”€ */}
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

          {/* Legend */}
          <div className="map-crowd-legend">
            <span className="legend-title">CROWD LEVEL</span>
            <span className="legend-item"><span className="legend-dot green"></span> Low</span>
            <span className="legend-item"><span className="legend-dot yellow"></span> Medium</span>
            <span className="legend-item"><span className="legend-dot red"></span> High</span>
            <span className="legend-item"><span className="legend-dot black"></span> Stop</span>
          </div>

          {/* MapTiler credit */}
          <div style={{
            position:'absolute', bottom:'8px', right:'8px', fontSize:'10px',
            color:'#9ca3af', zIndex:1000, background:'rgba(255,255,255,0.7)',
            padding:'2px 6px', borderRadius:'4px', pointerEvents:'none',
          }}>
            Â© <a href="https://www.maptiler.com/" style={{ color:'#6b7280' }}>MapTiler</a>
          </div>

          {/* Live badge */}
          <div style={{
            position:'absolute', top:'12px', right:'12px', zIndex:1000,
            background: withGps.length > 0 ? '#16a34a' : '#6b7280',
            color:'white', padding:'6px 12px', borderRadius:'8px',
            fontSize:'12px', fontWeight:700, boxShadow:'0 2px 8px rgba(0,0,0,0.2)',
          }}>
            {withGps.length} BUS{withGps.length !== 1 ? 'ES' : ''} LIVE
          </div>

          {/* Routes badge */}
          {showRoutes && drawableRoutes.length > 0 && (
            <div style={{
              position:'absolute', top:'12px', left:'12px', zIndex:1000,
              background:'#1a1a2e', color:'white', padding:'6px 12px',
              borderRadius:'8px', fontSize:'12px', fontWeight:700,
              boxShadow:'0 2px 8px rgba(0,0,0,0.3)',
            }}>
              {drawableRoutes.length} ROUTE{drawableRoutes.length !== 1 ? 'S' : ''} SHOWN
            </div>
          )}

          {withoutGps.length > 0 && (
            <div style={{
              position:'absolute', bottom:'60px', left:'12px', zIndex:1000,
              background:'white', padding:'8px 12px', borderRadius:'8px',
              fontSize:'12px', color:'#6b7280', boxShadow:'0 2px 8px rgba(0,0,0,0.15)',
            }}>
              âš  {withoutGps.length} bus{withoutGps.length > 1 ? 'es' : ''} offline
            </div>
          )}
        </div>

        {/* Side panel */}
        <div className="bus-detail-panel">
          {selected ? (
            <>
              <div className="bus-detail-header">
                <h2>{selected.bus_number} â€“ Selected</h2>
                <p>Route {selected.bus_routes?.route_number || 'N/A'} Â· {selected.bus_routes?.route_name || 'â€“'}</p>
              </div>
              <div className="bus-detail-rows">
                {([
                  ['BUS NUMBER', selected.bus_number],
                  ['DRIVER',     selected.driver_name || 'â€“'],
                  ['ROUTE',      selected.bus_routes
                    ? `${selected.bus_routes.route_number} â€“ ${selected.bus_routes.origin} â†’ ${selected.bus_routes.destination}`
                    : 'Unassigned'],
                  ['SPEED',      selected.speed_kmh ? `${selected.speed_kmh.toFixed(0)} km/h` : 'No GPS'],
                  ['STATUS',     selected.status],
                  ['GPS AGE',    selected.last_location_update
                    ? isRecentlyUpdated(selected.last_location_update) ? 'âœ… Live' : 'âš ï¸ Stale'
                    : 'Never'],
                  ['LAST GPS',   selected.last_location_update
                    ? new Date(selected.last_location_update).toLocaleTimeString()
                    : 'Never'],
                  ['RATING',     selected.avg_rating != null
                    ? `${'★'.repeat(Math.round(selected.avg_rating))}${'☆'.repeat(5 - Math.round(selected.avg_rating))} ${selected.avg_rating.toFixed(1)} (${selected.total_reviews} reviews)`
                    : 'No ratings yet'],
                ] as [string, string][]).map(([label, value]) => (
                  <div key={label} className="detail-row">
                    <span className="detail-label">{label}</span>
                    <span className="detail-value">{value}</span>
                  </div>
                ))}
                <div className="detail-row">
                  <span className="detail-label">CROWD</span>
                  <span style={{
                    color: getCrowdLabel(selected).color,
                    background: getCrowdLabel(selected).bg,
                    padding: '2px 8px', borderRadius: '6px',
                    fontSize: '12px', fontWeight: 600,
                  }}>
                    {getCrowdLabel(selected).label}
                  </span>
                </div>
              </div>
              <div className="bus-detail-actions">
                <button className="detail-action-btn secondary" onClick={() => setSelected(null)}>
                  <User size={16} /> Deselect
                </button>
              </div>
            </>
          ) : (
            <div style={{ padding:'24px', textAlign:'center', color:'#9ca3af' }}>
              <Bus size={32} style={{ margin:'0 auto 12px', display:'block', opacity:0.3 }} />
              <p style={{ fontSize:'14px' }}>Click a bus on the map to see its details</p>
              <p style={{ fontSize:'12px', marginTop:'8px' }}>
                {withGps.length} buses live Â· {withoutGps.length} offline
              </p>
              {showRoutes && (
                <p style={{ fontSize:'12px', marginTop:'4px', color:'#6b7280' }}>
                  {drawableRoutes.length} route{drawableRoutes.length !== 1 ? 's' : ''} displayed
                </p>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}