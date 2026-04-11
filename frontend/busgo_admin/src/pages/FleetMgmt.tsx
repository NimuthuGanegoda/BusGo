import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Download, Bus, Pencil, MapPin, RotateCcw, Wrench, X, CheckCircle } from 'lucide-react';
import { activeBuses as initialBuses, standbyBuses, fleetStats } from '../data/mockData';
import type { Bus as BusType } from '../types';
import './FleetMgmt.css';

export default function FleetMgmt() {
  const navigate = useNavigate();
  const [buses, setBuses] = useState<BusType[]>(initialBuses);
  const [routeFilter, setRouteFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [editBus, setEditBus] = useState<BusType | null>(null);
  const [editForm, setEditForm] = useState({ driver: '', route: '' });
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  };

  const getCrowdLevel = (passengers: number, capacity: number) => {
    const ratio = passengers / capacity;
    if (ratio > 0.8) return 'high';
    if (ratio > 0.5) return 'moderate';
    return 'low';
  };

  const filteredBuses = buses.filter((bus) => {
    if (routeFilter !== 'all' && String(bus.route) !== routeFilter) return false;
    if (statusFilter !== 'all' && bus.status !== statusFilter) return false;
    return true;
  });

  const handleEdit = (bus: BusType) => {
    setEditBus(bus);
    setEditForm({ driver: bus.driver, route: String(bus.route) });
  };

  const handleEditSave = () => {
    if (!editBus) return;
    setBuses((prev) =>
      prev.map((b) =>
        b.id === editBus.id
          ? { ...b, driver: editForm.driver, route: Number(editForm.route) }
          : b
      )
    );
    showToast(`${editBus.id} updated successfully`);
    setEditBus(null);
  };

  const handleTrack = (_bus: BusType) => {
    navigate('/admin/fleet-map');
  };

  const handleRecall = (bus: BusType) => {
    setBuses((prev) =>
      prev.map((b) =>
        b.id === bus.id
          ? { ...b, status: 'Standby' as const, speed: 0, passengers: 0 }
          : b
      )
    );
    showToast(`${bus.id} has been recalled to depot`);
  };

  const handleRepair = (bus: BusType) => {
    setBuses((prev) =>
      prev.map((b) =>
        b.id === bus.id
          ? { ...b, status: 'In Repair' as const }
          : b
      )
    );
    showToast(`${bus.id} sent to repair`);
  };

  const handleDeploy = (busId: string) => {
    showToast(`${busId} has been deployed`);
  };

  return (
    <div className="fleet-mgmt-page">
      {/* Toast */}
      {toast && (
        <div className="fleet-toast">
          <CheckCircle size={16} />
          <span>{toast}</span>
          <button onClick={() => setToast(null)}><X size={14} /></button>
        </div>
      )}

      {/* Edit Modal */}
      {editBus && (
        <div className="fleet-modal-overlay" onClick={() => setEditBus(null)}>
          <div className="fleet-modal" onClick={(e) => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Edit Bus - {editBus.id}</h3>
              <button className="fleet-modal-close" onClick={() => setEditBus(null)}>
                <X size={20} />
              </button>
            </div>
            <div className="fleet-modal-body">
              <div className="fleet-modal-field">
                <label>Bus ID</label>
                <input type="text" value={editBus.id} disabled className="fleet-modal-input disabled" />
              </div>
              <div className="fleet-modal-field">
                <label>Registration</label>
                <input type="text" value={editBus.registration} disabled className="fleet-modal-input disabled" />
              </div>
              <div className="fleet-modal-field">
                <label>Driver</label>
                <input
                  type="text"
                  value={editForm.driver}
                  onChange={(e) => setEditForm((f) => ({ ...f, driver: e.target.value }))}
                  className="fleet-modal-input"
                />
              </div>
              <div className="fleet-modal-field">
                <label>Route</label>
                <input
                  type="number"
                  value={editForm.route}
                  onChange={(e) => setEditForm((f) => ({ ...f, route: e.target.value }))}
                  className="fleet-modal-input"
                />
              </div>
              <div className="fleet-modal-actions">
                <button className="fleet-modal-btn cancel" onClick={() => setEditBus(null)}>Cancel</button>
                <button className="fleet-modal-btn save" onClick={handleEditSave}>Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="fleet-mgmt-header">
        <h1>Fleet Management</h1>
        <div className="fleet-mgmt-actions">
          <button className="fleet-btn primary">
            <Plus size={16} /> Register Bus
          </button>
          <button className="fleet-btn outline">
            <Download size={16} /> Export Report
          </button>
        </div>
      </div>

      <div className="fleet-stats-grid">
        <div className="fleet-stat-card">
          <div className="fleet-stat-value blue">{fleetStats.totalFleet}</div>
          <div className="fleet-stat-label">Total Fleet</div>
        </div>
        <div className="fleet-stat-card">
          <div className="fleet-stat-value green">{fleetStats.active}</div>
          <div className="fleet-stat-label">Active</div>
        </div>
        <div className="fleet-stat-card">
          <div className="fleet-stat-value orange">{fleetStats.standby}</div>
          <div className="fleet-stat-label">Standby</div>
        </div>
        <div className="fleet-stat-card">
          <div className="fleet-stat-value red">{fleetStats.inRepair}</div>
          <div className="fleet-stat-label">In Repair</div>
        </div>
      </div>

      <div className="fleet-section">
        <div className="fleet-section-header">
          <h2>Active Buses <span className="section-count">{filteredBuses.length} buses</span></h2>
          <div className="fleet-section-filters">
            <select value={routeFilter} onChange={(e) => setRouteFilter(e.target.value)} className="fleet-filter">
              <option value="all">Route</option>
              <option value="138">Route 138</option>
              <option value="220">Route 220</option>
              <option value="176">Route 176</option>
            </select>
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="fleet-filter">
              <option value="all">Status</option>
              <option value="Active">Active</option>
              <option value="Breakdown">Breakdown</option>
            </select>
          </div>
        </div>

        <div className="fleet-table-wrap">
          <table className="fleet-table">
            <thead>
              <tr>
                <th>BUS ID</th>
                <th>REGISTRATION</th>
                <th>ROUTE</th>
                <th>DRIVER</th>
                <th>PASSENGERS</th>
                <th>STATUS</th>
                <th>ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {filteredBuses.map((bus) => {
                const crowd = getCrowdLevel(bus.passengers, bus.capacity);
                return (
                  <tr key={bus.id}>
                    <td className="bus-id-cell">{bus.id}</td>
                    <td>{bus.registration}</td>
                    <td>
                      <span className="route-badge">Route {bus.route}</span>
                    </td>
                    <td>{bus.driver}</td>
                    <td>
                      <div className="passengers-cell">
                        <div className="mini-bar">
                          <div className={`mini-bar-fill ${crowd}`} style={{ width: `${(bus.passengers / bus.capacity) * 100}%` }}></div>
                        </div>
                        <span>{bus.passengers}/{bus.capacity}</span>
                      </div>
                    </td>
                    <td>
                      <span className={`fleet-status-badge ${bus.status.toLowerCase().replace(' ', '-')}`}>
                        {bus.status === 'Breakdown' && '\u26A0 '}
                        {bus.status}
                      </span>
                    </td>
                    <td>
                      <div className="fleet-action-btns">
                        <button className="fleet-action-btn blue" onClick={() => handleEdit(bus)}>
                          <Pencil size={14} /> Edit
                        </button>
                        <button className="fleet-action-btn gray" onClick={() => handleTrack(bus)}>
                          <MapPin size={14} /> Track
                        </button>
                        {bus.status === 'Active' && (
                          <button className="fleet-action-btn orange" onClick={() => handleRecall(bus)}>
                            <RotateCcw size={14} /> Recall
                          </button>
                        )}
                        {bus.status === 'Breakdown' && (
                          <button className="fleet-action-btn red" onClick={() => handleRepair(bus)}>
                            <Wrench size={14} /> Repair
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      <div className="fleet-section">
        <div className="fleet-section-header">
          <h2>Standby Buses <span className="section-count">{standbyBuses.length} available</span></h2>
        </div>
        <div className="standby-grid">
          {standbyBuses.map((bus) => (
            <div key={bus.id} className="standby-card">
              <div className="standby-card-id">{bus.id}</div>
              <div className="standby-card-reg">{bus.registration}</div>
              <button className="standby-deploy-btn" onClick={() => handleDeploy(bus.id)}>
                <Bus size={14} /> Deploy
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
