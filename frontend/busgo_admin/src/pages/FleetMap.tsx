import { useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { RefreshCw, Crosshair, Bus, User } from 'lucide-react';
import { activeBuses } from '../data/mockData';
import type { Bus as BusType } from '../types';
import './FleetMap.css';

function createBusIcon(passengers: number, capacity: number, status: string) {
  const ratio = passengers / capacity;
  let color = '#4caf50';
  if (status === 'Breakdown') color = '#e74c3c';
  else if (ratio > 0.8) color = '#e74c3c';
  else if (ratio > 0.5) color = '#f59e0b';

  return L.divIcon({
    className: 'custom-bus-marker',
    html: `<div style="background:${color};width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#fff;font-size:11px;font-weight:700;border:3px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,0.3);">${passengers}</div>`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
  });
}

const allBuses: BusType[] = [
  ...activeBuses,
  { id: 'BUS-74-D', registration: 'WP-XX-7400', route: 74, driver: 'Nimal P.', passengers: 20, capacity: 50, status: 'Active', speed: 40, lat: 6.89, lng: 79.92, lastUpdated: '14:30' },
  { id: 'BUS-24-E', registration: 'WP-YY-2400', route: 24, driver: 'Ajith K.', passengers: 38, capacity: 50, status: 'Active', speed: 22, lat: 6.88, lng: 79.96, lastUpdated: '14:31' },
  { id: 'BUS-55-F', registration: 'WP-ZZ-5500', route: 55, driver: 'Sunil R.', passengers: 45, capacity: 50, status: 'Active', speed: 15, lat: 6.87, lng: 80.02, lastUpdated: '14:29' },
  { id: 'BUS-110-G', registration: 'SP-AA-1100', route: 110, driver: 'Kumara S.', passengers: 12, capacity: 50, status: 'Active', speed: 50, lat: 6.82, lng: 79.88, lastUpdated: '14:28' },
  { id: 'BUS-76-H', registration: 'SP-BB-7600', route: 76, driver: 'Lalith M.', passengers: 28, capacity: 50, status: 'Active', speed: 32, lat: 6.82, lng: 79.95, lastUpdated: '14:27' },
  { id: 'BUS-92-I', registration: 'CP-CC-9200', route: 92, driver: 'Rohan D.', passengers: 35, capacity: 50, status: 'Active', speed: 18, lat: 6.82, lng: 80.01, lastUpdated: '14:26' },
  { id: 'BUS-103-J', registration: 'CP-DD-1030', route: 103, driver: 'Asanka J.', passengers: 22, capacity: 50, status: 'Active', speed: 45, lat: 6.80, lng: 80.08, lastUpdated: '14:25' },
];

export default function FleetMap() {
  const [selectedBus, setSelectedBus] = useState<BusType>(allBuses[0]);
  const [routeFilter, setRouteFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [crowdFilter, setCrowdFilter] = useState('all');

  const getCrowdLevel = (bus: BusType) => {
    const ratio = bus.passengers / bus.capacity;
    if (ratio > 0.8) return 'high';
    if (ratio > 0.5) return 'moderate';
    return 'low';
  };

  const filteredBuses = allBuses.filter((bus) => {
    if (statusFilter !== 'all' && bus.status !== statusFilter) return false;
    if (crowdFilter !== 'all' && getCrowdLevel(bus) !== crowdFilter) return false;
    return true;
  });

  const crowdPercent = Math.round((selectedBus.passengers / selectedBus.capacity) * 100);
  const crowdLabel = getCrowdLevel(selectedBus);

  return (
    <div className="fleet-map-page">
      <div className="fleet-map-toolbar">
        <select value={routeFilter} onChange={(e) => setRouteFilter(e.target.value)} className="map-filter">
          <option value="all">All Routes</option>
          <option value="138">Route 138</option>
          <option value="220">Route 220</option>
          <option value="176">Route 176</option>
        </select>
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="map-filter">
          <option value="all">All Status</option>
          <option value="Active">Active</option>
          <option value="Breakdown">Breakdown</option>
        </select>
        <select value={crowdFilter} onChange={(e) => setCrowdFilter(e.target.value)} className="map-filter">
          <option value="all">Crowd Level</option>
          <option value="low">Low</option>
          <option value="moderate">Moderate</option>
          <option value="high">High</option>
        </select>
        <div className="map-toolbar-right">
          <button className="map-btn"><RefreshCw size={16} /> Refresh</button>
          <button className="map-btn primary"><Crosshair size={16} /> Center Map</button>
        </div>
      </div>

      <div className="fleet-map-content">
        <div className="fleet-map-container">
          <MapContainer
            center={[6.85, 79.95]}
            zoom={12}
            style={{ height: '100%', width: '100%' }}
            zoomControl={false}
          >
            <TileLayer
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; OpenStreetMap contributors'
            />
            {filteredBuses.map((bus) => (
              <Marker
                key={bus.id}
                position={[bus.lat!, bus.lng!]}
                icon={createBusIcon(bus.passengers, bus.capacity, bus.status)}
                eventHandlers={{
                  click: () => setSelectedBus(bus),
                }}
              >
                <Popup>{bus.id}</Popup>
              </Marker>
            ))}
          </MapContainer>
          <div className="map-crowd-legend">
            <span className="legend-title">CROWD LEVEL</span>
            <span className="legend-item"><span className="legend-dot green"></span> Low</span>
            <span className="legend-item"><span className="legend-dot yellow"></span> Moderate</span>
            <span className="legend-item"><span className="legend-dot red"></span> High</span>
          </div>
        </div>

        <div className="bus-detail-panel">
          <div className="bus-detail-header">
            <h2>{selectedBus.id.replace('BUS-', 'Bus #')} — Selected</h2>
            <p>Route {selectedBus.route} · Last updated {selectedBus.lastUpdated}</p>
          </div>

          <div className="bus-detail-rows">
            <div className="detail-row">
              <span className="detail-label">BUS ID</span>
              <span className="detail-value">{selectedBus.id}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">ROUTE</span>
              <span className="detail-value">{selectedBus.route} — Fort — Homagama</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">DRIVER</span>
              <span className="detail-value">{selectedBus.driver}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">SPEED</span>
              <span className="detail-value">{selectedBus.speed} km/h</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">STATUS</span>
              <span className={`detail-status ${selectedBus.status.toLowerCase()}`}>
                <span className="status-indicator"></span>
                {selectedBus.status}
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">PASSENGERS</span>
              <span className="detail-value">{selectedBus.passengers} / {selectedBus.capacity}</span>
            </div>
            <div className="passenger-bar-wrap">
              <div className="passenger-bar">
                <div
                  className={`passenger-bar-fill ${crowdLabel}`}
                  style={{ width: `${crowdPercent}%` }}
                ></div>
              </div>
              <span className={`crowd-label ${crowdLabel}`}>
                {crowdLabel.charAt(0).toUpperCase() + crowdLabel.slice(1)} — {crowdPercent}%
              </span>
            </div>
            <div className="detail-row">
              <span className="detail-label">NEXT STOP</span>
              <span className="detail-value bold">{selectedBus.nextStop || 'N/A'}</span>
            </div>
            <div className="detail-row">
              <span className="detail-label">ETA</span>
              <span className="detail-value bold">{selectedBus.eta ? `${selectedBus.eta} minutes` : 'N/A'}</span>
            </div>
          </div>

          <div className="bus-detail-actions">
            <button className="detail-action-btn primary">
              <Bus size={16} /> Deploy Standby Bus
            </button>
            <button className="detail-action-btn secondary">
              <User size={16} /> View Driver Profile
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
