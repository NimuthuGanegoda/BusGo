import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Bus, Pencil, MapPin, RotateCcw, X, CheckCircle, RefreshCw } from 'lucide-react';
import './FleetMgmt.css';

const API   = 'https://busgo-production.up.railway.app/api/admin';
const token = () => localStorage.getItem('busgo_access_token') ?? '';

// CHANGE 1 — added driver_user_id to BusRecord, added DriverRecord type
type BusRecord = {
  id: string;
  bus_number: string;
  driver_name: string;
  driver_phone: string;
  driver_user_id: string | null;
  status: string;
  crowd_level: string;
  speed_kmh: number | null;
  last_location_update: string | null;
  bus_routes: { id: string; route_number: string; route_name: string } | null;
  avg_rating:    number | null;
  total_reviews: number;
};
type RouteRecord  = { id: string; route_number: string; route_name: string };
type DriverRecord = { id: string; full_name: string; phone: string | null };

export default function FleetMgmt() {
  const navigate = useNavigate();

  const [buses,        setBuses]        = useState<BusRecord[]>([]);
  const [standby,      setStandby]      = useState<BusRecord[]>([]);
  const [routes,       setRoutes]       = useState<RouteRecord[]>([]);
  const [drivers,      setDrivers]      = useState<DriverRecord[]>([]); // CHANGE 2
  const [loading,      setLoading]      = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [toast,        setToast]        = useState('');
  const [toastType,    setToastType]    = useState<'success' | 'error'>('success');

  // Modals
  const [showAdd,     setShowAdd]     = useState(false);
  const [editBus,     setEditBus]     = useState<BusRecord | null>(null);
  const [deployBus,   setDeployBus]   = useState<BusRecord | null>(null);
  const [deployRoute, setDeployRoute] = useState('');

  // CHANGE 3 — added driver_user_id to both form states
  const [addForm,    setAddForm]    = useState({ bus_number: '', driver_user_id: '', driver_name: '', driver_phone: '', route_id: '' });
  const [editForm,   setEditForm]   = useState({ driver_user_id: '', driver_name: '', driver_phone: '', route_id: '', status: '' });
  const [addLoading, setAddLoading] = useState(false);
  const [addError,   setAddError]   = useState('');

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast(msg); setToastType(type);
    setTimeout(() => setToast(''), 4000);
  };

  // CHANGE 4 — added driver fetch to fetchAll
  const fetchAll = useCallback(async () => {
    setLoading(true);
    try {
      const [busRes, standbyRes, routeRes, driverRes] = await Promise.all([
        fetch(`${API}/buses?page_size=100`,                              { headers: { Authorization: `Bearer ${token()}` } }),
        fetch(`${API}/fleet/standby`,                                    { headers: { Authorization: `Bearer ${token()}` } }),
        fetch(`https://busgo-production.up.railway.app/api/routes`,      { headers: { Authorization: `Bearer ${token()}` } }),
        fetch(`${API}/users?role=driver&is_active=true&page_size=100`,   { headers: { Authorization: `Bearer ${token()}` } }),
      ]);
      const [bj, sj, rj, dj] = await Promise.all([
        busRes.json(), standbyRes.json(), routeRes.json(), driverRes.json(),
      ]);
      setBuses(Array.isArray(bj.data) ? bj.data : []);
      setStandby(Array.isArray(sj.data) ? sj.data : []);
      setRoutes(Array.isArray(rj.data) ? rj.data : []);
      setDrivers(Array.isArray(dj.data) ? dj.data : []);
    } catch (e) { console.error('[FleetMgmt]', e); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const filtered = buses.filter(b =>
    statusFilter === 'all' || b.status === statusFilter
  );

  // ── Register bus ──────────────────────────────────────────────────────────
  // CHANGE 5 — validate driver selection, send driver_user_id correctly
  const handleAdd = async () => {
    if (!addForm.bus_number)     { setAddError('Bus number is required'); return; }
    if (!addForm.driver_user_id) { setAddError('Please select a driver'); return; }
    setAddLoading(true); setAddError('');
    try {
      const res = await fetch(`${API}/buses`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify({
          ...addForm,
          driver_user_id: addForm.driver_user_id || null,
          route_id:       addForm.route_id       || null,
          status:         'active',
          crowd_level:    'low',
        }),
      });
      const json = await res.json();
      if (!res.ok) { setAddError(json.message || 'Failed to register bus'); return; }
      setShowAdd(false);
      setAddForm({ bus_number: '', driver_user_id: '', driver_name: '', driver_phone: '', route_id: '' });
      showToast(`✅ Bus ${addForm.bus_number} registered`);
      fetchAll();
    } catch { setAddError('Connection failed'); }
    finally { setAddLoading(false); }
  };

  // ── Edit bus ──────────────────────────────────────────────────────────────
  // CHANGE 6 — openEdit now captures driver_user_id from the bus record
  const openEdit = (bus: BusRecord) => {
    setEditBus(bus);
    setEditForm({
      driver_user_id: bus.driver_user_id || '',
      driver_name:    bus.driver_name    || '',
      driver_phone:   bus.driver_phone   || '',
      route_id:       bus.bus_routes?.id || '',
      status:         bus.status,
    });
  };

  // CHANGE 7 — handleEdit sends driver_user_id and route_id as null when empty
  const handleEdit = async () => {
    if (!editBus) return;
    try {
      const res = await fetch(`${API}/buses/${editBus.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify({
          ...editForm,
          driver_user_id: editForm.driver_user_id || null,
          route_id:       editForm.route_id       || null,
        }),
      });
      if (!res.ok) throw new Error();
      setBuses(prev => prev.map(b => b.id === editBus.id ? { ...b, ...editForm } : b));
      setEditBus(null);
      showToast(`✅ ${editBus.bus_number} updated`);
    } catch { showToast('❌ Failed to update bus', 'error'); }
  };

  // ── Recall bus ────────────────────────────────────────────────────────────
  const handleRecall = async (bus: BusRecord) => {
    try {
      const res = await fetch(`${API}/fleet/${bus.id}/recall`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${token()}` },
      });
      if (!res.ok) throw new Error();
      showToast(`✅ ${bus.bus_number} recalled to standby`);
      fetchAll();
    } catch { showToast('❌ Failed to recall bus', 'error'); }
  };

  // ── Deploy standby bus ────────────────────────────────────────────────────
  const handleDeploy = async () => {
    if (!deployBus || !deployRoute) { showToast('❌ Select a route first', 'error'); return; }
    try {
      const res = await fetch(`${API}/fleet/${deployBus.id}/deploy`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify({ route_id: deployRoute }),
      });
      if (!res.ok) throw new Error();
      showToast(`✅ ${deployBus.bus_number} deployed`);
      setDeployBus(null); setDeployRoute('');
      fetchAll();
    } catch { showToast('❌ Failed to deploy bus', 'error'); }
  };

  // ── Delete bus ────────────────────────────────────────────────────────────
  const handleDelete = async (bus: BusRecord) => {
    if (!confirm(`Delete bus ${bus.bus_number}? This cannot be undone.`)) return;
    try {
      await fetch(`${API}/buses/${bus.id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token()}` } });
      setBuses(prev => prev.filter(b => b.id !== bus.id));
      showToast(`✅ ${bus.bus_number} deleted`);
    } catch { showToast('❌ Failed to delete', 'error'); }
  };

  const stats = {
    total:     buses.length,
    active:    buses.filter(b => b.status === 'active').length,
    standby:   standby.length,
    breakdown: buses.filter(b => b.status === 'breakdown').length,
  };

  return (
    <div className="fleet-mgmt-page">

      {/* Toast */}
      {toast && (
        <div className="fleet-toast" style={{ background: toastType === 'error' ? '#dc2626' : '#16a34a' }}>
          <CheckCircle size={16} /><span>{toast}</span>
          <button onClick={() => setToast('')}><X size={14} /></button>
        </div>
      )}

      {/* ── Add Modal ── */}
      {showAdd && (
        <div className="fleet-modal-overlay" onClick={() => setShowAdd(false)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Register New Bus</h3>
              <button className="fleet-modal-close" onClick={() => setShowAdd(false)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">
              {addError && (
                <div style={{ background: '#fef2f2', border: '1px solid #fca5a5', borderRadius: '8px', padding: '10px', color: '#dc2626', fontSize: '13px', marginBottom: '12px' }}>
                  {addError}
                </div>
              )}

              {/* Bus Number */}
              <div className="fleet-modal-field">
                <label>Bus Number *</label>
                <input
                  className="fleet-modal-input"
                  placeholder="e.g. NB-1234"
                  value={addForm.bus_number}
                  onChange={e => setAddForm(p => ({ ...p, bus_number: e.target.value }))}
                />
              </div>

              {/* CHANGE 8 — Driver dropdown replaces driver name/phone text inputs */}
              <div className="fleet-modal-field">
                <label>Assign Driver *</label>
                <select
                  className="fleet-modal-input"
                  value={addForm.driver_user_id}
                  onChange={e => {
                    const chosen = drivers.find(d => d.id === e.target.value);
                    setAddForm(p => ({
                      ...p,
                      driver_user_id: e.target.value,
                      driver_name:    chosen?.full_name || '',
                      driver_phone:   chosen?.phone     || '',
                    }));
                  }}
                >
                  <option value="">— Select a driver —</option>
                  {drivers.map(d => (
                    <option key={d.id} value={d.id}>
                      {d.full_name}{d.phone ? ` (${d.phone})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              {/* Route */}
              <div className="fleet-modal-field">
                <label>Route</label>
                <select
                  className="fleet-modal-input"
                  value={addForm.route_id}
                  onChange={e => setAddForm(p => ({ ...p, route_id: e.target.value }))}
                >
                  <option value="">Select route</option>
                  {routes.map(r => (
                    <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>
                  ))}
                </select>
              </div>

              <div className="fleet-modal-actions">
                <button className="fleet-modal-btn cancel" onClick={() => setShowAdd(false)}>Cancel</button>
                <button className="fleet-modal-btn save" onClick={handleAdd} disabled={addLoading}>
                  {addLoading ? 'Registering...' : 'Register Bus'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Edit Modal ── */}
      {editBus && (
        <div className="fleet-modal-overlay" onClick={() => setEditBus(null)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Edit Bus — {editBus.bus_number}</h3>
              <button className="fleet-modal-close" onClick={() => setEditBus(null)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">

              {/* Bus Number — read only */}
              <div className="fleet-modal-field">
                <label>Bus Number</label>
                <input className="fleet-modal-input disabled" value={editBus.bus_number} disabled />
              </div>

              {/* CHANGE 9 — Driver dropdown replaces driver name/phone text inputs */}
              <div className="fleet-modal-field">
                <label>Assign Driver</label>
                <select
                  className="fleet-modal-input"
                  value={editForm.driver_user_id}
                  onChange={e => {
                    const chosen = drivers.find(d => d.id === e.target.value);
                    setEditForm(p => ({
                      ...p,
                      driver_user_id: e.target.value,
                      driver_name:    chosen?.full_name || '',
                      driver_phone:   chosen?.phone     || '',
                    }));
                  }}
                >
                  <option value="">— Unassigned —</option>
                  {drivers.map(d => (
                    <option key={d.id} value={d.id}>
                      {d.full_name}{d.phone ? ` (${d.phone})` : ''}
                    </option>
                  ))}
                </select>
              </div>

              {/* Route */}
              <div className="fleet-modal-field">
                <label>Route</label>
                <select
                  className="fleet-modal-input"
                  value={editForm.route_id}
                  onChange={e => setEditForm(p => ({ ...p, route_id: e.target.value }))}
                >
                  <option value="">No route</option>
                  {routes.map(r => (
                    <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>
                  ))}
                </select>
              </div>

              {/* Status */}
              <div className="fleet-modal-field">
                <label>Status</label>
                <select
                  className="fleet-modal-input"
                  value={editForm.status}
                  onChange={e => setEditForm(p => ({ ...p, status: e.target.value }))}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="breakdown">Breakdown</option>
                </select>
              </div>

              <div className="fleet-modal-actions">
                <button className="fleet-modal-btn cancel" onClick={() => setEditBus(null)}>Cancel</button>
                <button className="fleet-modal-btn save" onClick={handleEdit}>Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Deploy Modal — unchanged ── */}
      {deployBus && (
        <div className="fleet-modal-overlay" onClick={() => setDeployBus(null)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Deploy {deployBus.bus_number}</h3>
              <button className="fleet-modal-close" onClick={() => setDeployBus(null)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">
              <div className="fleet-modal-field">
                <label>Select Route</label>
                <select
                  className="fleet-modal-input"
                  value={deployRoute}
                  onChange={e => setDeployRoute(e.target.value)}
                >
                  <option value="">Select route</option>
                  {routes.map(r => (
                    <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>
                  ))}
                </select>
              </div>
              <div className="fleet-modal-actions">
                <button className="fleet-modal-btn cancel" onClick={() => setDeployBus(null)}>Cancel</button>
                <button className="fleet-modal-btn save" onClick={handleDeploy}>Deploy Bus</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className="fleet-mgmt-header">
        <h1>Fleet Management</h1>
        <div className="fleet-mgmt-actions">
          <button className="fleet-btn primary" onClick={() => setShowAdd(true)}><Plus size={16} /> Register Bus</button>
          <button className="fleet-btn outline" onClick={fetchAll}><RefreshCw size={16} /> Refresh</button>
        </div>
      </div>

      {/* Stats */}
      <div className="fleet-stats-grid">
        {[
          { value: stats.total,     label: 'Total Fleet', cls: 'blue' },
          { value: stats.active,    label: 'Active',      cls: 'green' },
          { value: stats.standby,   label: 'Standby',     cls: 'orange' },
          { value: stats.breakdown, label: 'Breakdown',   cls: 'red' },
        ].map(s => (
          <div key={s.label} className="fleet-stat-card">
            <div className={`fleet-stat-value ${s.cls}`}>{s.value}</div>
            <div className="fleet-stat-label">{s.label}</div>
          </div>
        ))}
      </div>

      {/* Fleet Overview */}
      <div className="fleet-section">
        <div className="fleet-section-header">
          <h2>Fleet Overview <span className="section-count">{filtered.length} buses</span></h2>
          <div className="fleet-section-filters">
            <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="fleet-filter">
              <option value="all">All Status</option>
              <option value="active">Active</option>
              <option value="breakdown">Breakdown</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
        </div>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#6b7280' }}>Loading fleet...</div>
        ) : (
          <div className="fleet-table-wrap">
            <table className="fleet-table">
              <thead>
                <tr>
                  <th>BUS NUMBER</th><th>ROUTE</th><th>DRIVER</th><th>PHONE</th>
                  <th>RATING</th><th>CROWD</th><th>STATUS</th><th>LAST GPS</th><th>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {filtered.length === 0 && (
                  <tr>
                    <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>
                      No buses found
                    </td>
                  </tr>
                )}
                {filtered.map(bus => (
                  <tr key={bus.id}>
                    <td className="bus-id-cell">{bus.bus_number}</td>
                    <td>
                      {bus.bus_routes
                        ? <span className="route-badge">Route {bus.bus_routes.route_number}</span>
                        : <span style={{ color: '#f59e0b', fontSize: '12px' }}>Unassigned</span>}
                    </td>
                    <td>{bus.driver_name || '—'}</td>
                    <td>{bus.driver_phone || '—'}</td>
                    <td>
                      {bus.avg_rating != null ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                          <span style={{ fontSize: '13px', fontWeight: 700, color: '#1d4ed8' }}>{bus.avg_rating.toFixed(1)}</span>
                          <span style={{ fontSize: '11px', color: '#6b7280' }}>/ 10</span>
                          <span style={{ fontSize: '11px', color: '#9ca3af' }}>({bus.total_reviews} reviews)</span>
                        </div>
                      ) : (
                        <span style={{ fontSize: '12px', color: '#9ca3af' }}>No ratings</span>
                      )}
                    </td>
                    <td>
                      <span style={{
                        padding: '2px 8px', borderRadius: '6px', fontSize: '12px', fontWeight: 600,
                        background: bus.crowd_level === 'high' ? '#fef2f2' : bus.crowd_level === 'medium' ? '#fffbeb' : '#f0fdf4',
                        color:      bus.crowd_level === 'high' ? '#dc2626' : bus.crowd_level === 'medium' ? '#d97706' : '#16a34a',
                      }}>
                        {bus.crowd_level || 'low'}
                      </span>
                    </td>
                    <td>
                      <span className={`fleet-status-badge ${bus.status}`}>
                        {bus.status === 'breakdown' && '⚠ '}{bus.status}
                      </span>
                    </td>
                    <td style={{ fontSize: '12px', color: '#9ca3af' }}>
                      {bus.last_location_update
                        ? new Date(bus.last_location_update).toLocaleTimeString()
                        : 'No GPS'}
                    </td>
                    <td>
                      <div className="fleet-action-btns">
                        <button className="fleet-action-btn blue" onClick={() => openEdit(bus)}><Pencil size={14} /> Edit</button>
                        <button className="fleet-action-btn gray" onClick={() => navigate('/admin/fleet-map')}><MapPin size={14} /> Track</button>
                        {bus.status === 'active' && (
                          <button className="fleet-action-btn orange" onClick={() => handleRecall(bus)}><RotateCcw size={14} /> Recall</button>
                        )}
                        <button className="fleet-action-btn red" onClick={() => handleDelete(bus)}><X size={14} /> Delete</button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Standby Buses */}
      <div className="fleet-section">
        <div className="fleet-section-header">
          <h2>Standby Buses <span className="section-count">{standby.length} available</span></h2>
        </div>
        {standby.length === 0
          ? <div style={{ padding: '24px', textAlign: 'center', color: '#9ca3af', fontSize: '14px' }}>No standby buses</div>
          : (
            <div className="standby-grid">
              {standby.map(bus => (
                <div key={bus.id} className="standby-card">
                  <div className="standby-card-id">{bus.bus_number}</div>
                  <div className="standby-card-reg">{bus.driver_name || 'No driver'}</div>
                  <button className="standby-deploy-btn" onClick={() => { setDeployBus(bus); setDeployRoute(''); }}>
                    <Bus size={14} /> Deploy
                  </button>
                </div>
              ))}
            </div>
          )
        }
      </div>

    </div>
  );
}
