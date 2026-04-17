import { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Bus, Pencil, MapPin, RotateCcw, X, CheckCircle, RefreshCw } from 'lucide-react';
import './FleetMgmt.css';

const API   = 'http://localhost:5000/api/admin';
const token = () => localStorage.getItem('busgo_access_token') ?? '';

type BusRecord = {
  id: string;
  bus_number: string;
  driver_name: string;
  driver_phone: string;
  status: string;
  crowd_level: string;
  speed_kmh: number | null;
  last_location_update: string | null;
  bus_routes: { id: string; route_number: string; route_name: string } | null;
};
type RouteRecord = { id: string; route_number: string; route_name: string };

export default function FleetMgmt() {
  const navigate = useNavigate();

  const [buses,        setBuses]        = useState<BusRecord[]>([]);
  const [standby,      setStandby]      = useState<BusRecord[]>([]);
  const [routes,       setRoutes]       = useState<RouteRecord[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [toast,        setToast]        = useState('');
  const [toastType,    setToastType]    = useState<'success' | 'error'>('success');

  // Modals
  const [showAdd,    setShowAdd]    = useState(false);
  const [editBus,    setEditBus]    = useState<BusRecord | null>(null);
  const [deployBus,  setDeployBus]  = useState<BusRecord | null>(null);
  const [deployRoute, setDeployRoute] = useState('');
  const [addForm,    setAddForm]    = useState({ bus_number: '', driver_name: '', driver_phone: '', route_id: '' });
  const [editForm,   setEditForm]   = useState({ driver_name: '', driver_phone: '', route_id: '', status: '' });
  const [addLoading, setAddLoading] = useState(false);
  const [addError,   setAddError]   = useState('');

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast(msg); setToastType(type);
    setTimeout(() => setToast(''), 4000);
  };

  const fetchAll = useCallback(async () => {
    setLoading(true);
    try {
      const [busRes, standbyRes, routeRes] = await Promise.all([
        fetch(`${API}/buses?page_size=100`,          { headers: { Authorization: `Bearer ${token()}` } }),
        fetch(`${API}/fleet/standby`,                { headers: { Authorization: `Bearer ${token()}` } }),
        fetch(`http://localhost:5000/api/routes`,    { headers: { Authorization: `Bearer ${token()}` } }),
      ]);
      const [bj, sj, rj] = await Promise.all([busRes.json(), standbyRes.json(), routeRes.json()]);
      setBuses(Array.isArray(bj.data) ? bj.data : []);
      setStandby(Array.isArray(sj.data) ? sj.data : []);
      setRoutes(Array.isArray(rj.data) ? rj.data : []);
    } catch (e) { console.error('[FleetMgmt]', e); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll]);

  const filtered = buses.filter(b =>
    statusFilter === 'all' || b.status === statusFilter
  );

  // ── Register bus ──────────────────────────────────────────────────────────
  const handleAdd = async () => {
    if (!addForm.bus_number || !addForm.driver_name) { setAddError('Bus number and driver name required'); return; }
    setAddLoading(true); setAddError('');
    try {
      const res  = await fetch(`${API}/buses`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify({ ...addForm, status: 'active', crowd_level: 'low' }),
      });
      const json = await res.json();
      if (!res.ok) { setAddError(json.message || 'Failed to register bus'); return; }
      setShowAdd(false);
      setAddForm({ bus_number: '', driver_name: '', driver_phone: '', route_id: '' });
      showToast(`✅ Bus ${addForm.bus_number} registered`);
      fetchAll();
    } catch { setAddError('Connection failed'); }
    finally { setAddLoading(false); }
  };

  // ── Edit bus ──────────────────────────────────────────────────────────────
  const openEdit = (bus: BusRecord) => {
    setEditBus(bus);
    setEditForm({ driver_name: bus.driver_name || '', driver_phone: bus.driver_phone || '', route_id: bus.bus_routes?.id || '', status: bus.status });
  };
  const handleEdit = async () => {
    if (!editBus) return;
    try {
      const res = await fetch(`${API}/buses/${editBus.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify(editForm),
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

      {/* Add Modal */}
      {showAdd && (
        <div className="fleet-modal-overlay" onClick={() => setShowAdd(false)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Register New Bus</h3>
              <button className="fleet-modal-close" onClick={() => setShowAdd(false)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">
              {addError && <div style={{ background: '#fef2f2', border: '1px solid #fca5a5', borderRadius: '8px', padding: '10px', color: '#dc2626', fontSize: '13px', marginBottom: '12px' }}>{addError}</div>}
              {[
                { label: 'Bus Number *', key: 'bus_number', placeholder: 'e.g. NB-1234' },
                { label: 'Driver Name *', key: 'driver_name', placeholder: 'e.g. Nimal Perera' },
                { label: 'Driver Phone', key: 'driver_phone', placeholder: '+94 77 123 4567' },
              ].map(f => (
                <div key={f.key} className="fleet-modal-field">
                  <label>{f.label}</label>
                  <input className="fleet-modal-input" placeholder={f.placeholder}
                    value={(addForm as any)[f.key]}
                    onChange={e => setAddForm(p => ({ ...p, [f.key]: e.target.value }))} />
                </div>
              ))}
              <div className="fleet-modal-field">
                <label>Route</label>
                <select className="fleet-modal-input" value={addForm.route_id}
                  onChange={e => setAddForm(p => ({ ...p, route_id: e.target.value }))}>
                  <option value="">Select route</option>
                  {routes.map(r => <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>)}
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

      {/* Edit Modal */}
      {editBus && (
        <div className="fleet-modal-overlay" onClick={() => setEditBus(null)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Edit Bus — {editBus.bus_number}</h3>
              <button className="fleet-modal-close" onClick={() => setEditBus(null)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">
              <div className="fleet-modal-field"><label>Bus Number</label>
                <input className="fleet-modal-input disabled" value={editBus.bus_number} disabled /></div>
              {[
                { label: 'Driver Name', key: 'driver_name' },
                { label: 'Driver Phone', key: 'driver_phone' },
              ].map(f => (
                <div key={f.key} className="fleet-modal-field"><label>{f.label}</label>
                  <input className="fleet-modal-input" value={(editForm as any)[f.key]}
                    onChange={e => setEditForm(p => ({ ...p, [f.key]: e.target.value }))} /></div>
              ))}
              <div className="fleet-modal-field"><label>Route</label>
                <select className="fleet-modal-input" value={editForm.route_id}
                  onChange={e => setEditForm(p => ({ ...p, route_id: e.target.value }))}>
                  <option value="">No route</option>
                  {routes.map(r => <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>)}
                </select></div>
              <div className="fleet-modal-field"><label>Status</label>
                <select className="fleet-modal-input" value={editForm.status}
                  onChange={e => setEditForm(p => ({ ...p, status: e.target.value }))}>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                  <option value="breakdown">Breakdown</option>
                </select></div>
              <div className="fleet-modal-actions">
                <button className="fleet-modal-btn cancel" onClick={() => setEditBus(null)}>Cancel</button>
                <button className="fleet-modal-btn save" onClick={handleEdit}>Save Changes</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Deploy Modal */}
      {deployBus && (
        <div className="fleet-modal-overlay" onClick={() => setDeployBus(null)}>
          <div className="fleet-modal" onClick={e => e.stopPropagation()}>
            <div className="fleet-modal-header">
              <h3>Deploy {deployBus.bus_number}</h3>
              <button className="fleet-modal-close" onClick={() => setDeployBus(null)}><X size={20} /></button>
            </div>
            <div className="fleet-modal-body">
              <div className="fleet-modal-field"><label>Select Route</label>
                <select className="fleet-modal-input" value={deployRoute}
                  onChange={e => setDeployRoute(e.target.value)}>
                  <option value="">Select route</option>
                  {routes.map(r => <option key={r.id} value={r.id}>Route {r.route_number} — {r.route_name}</option>)}
                </select></div>
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

      {/* Active Buses */}
      <div className="fleet-section">
        <div className="fleet-section-header">
          <h2>Active Buses <span className="section-count">{filtered.length} buses</span></h2>
          <div className="fleet-section-filters">
            <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="fleet-filter">
              <option value="all">All Status</option>
              <option value="active">Active</option>
              <option value="breakdown">Breakdown</option>
              <option value="inactive">Inactive</option>
            </select>
          </div>
        </div>
        {loading ? <div style={{ padding: '40px', textAlign: 'center', color: '#6b7280' }}>Loading fleet...</div> : (
          <div className="fleet-table-wrap">
            <table className="fleet-table">
              <thead><tr>
                <th>BUS NUMBER</th><th>ROUTE</th><th>DRIVER</th><th>PHONE</th>
                <th>CROWD</th><th>STATUS</th><th>LAST GPS</th><th>ACTIONS</th>
              </tr></thead>
              <tbody>
                {filtered.length === 0 && <tr><td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>No buses found</td></tr>}
                {filtered.map(bus => (
                  <tr key={bus.id}>
                    <td className="bus-id-cell">{bus.bus_number}</td>
                    <td>{bus.bus_routes
                      ? <span className="route-badge">Route {bus.bus_routes.route_number}</span>
                      : <span style={{ color: '#f59e0b', fontSize: '12px' }}>Unassigned</span>}
                    </td>
                    <td>{bus.driver_name || '—'}</td>
                    <td>{bus.driver_phone || '—'}</td>
                    <td><span style={{
                      padding: '2px 8px', borderRadius: '6px', fontSize: '12px', fontWeight: 600,
                      background: bus.crowd_level === 'high' ? '#fef2f2' : bus.crowd_level === 'medium' ? '#fffbeb' : '#f0fdf4',
                      color:      bus.crowd_level === 'high' ? '#dc2626' : bus.crowd_level === 'medium' ? '#d97706' : '#16a34a',
                    }}>{bus.crowd_level || 'low'}</span></td>
                    <td><span className={`fleet-status-badge ${bus.status}`}>
                      {bus.status === 'breakdown' && '⚠ '}{bus.status}
                    </span></td>
                    <td style={{ fontSize: '12px', color: '#9ca3af' }}>
                      {bus.last_location_update ? new Date(bus.last_location_update).toLocaleTimeString() : 'No GPS'}
                    </td>
                    <td><div className="fleet-action-btns">
                      <button className="fleet-action-btn blue" onClick={() => openEdit(bus)}><Pencil size={14} /> Edit</button>
                      <button className="fleet-action-btn gray" onClick={() => navigate('/admin/fleet-map')}><MapPin size={14} /> Track</button>
                      {bus.status === 'active' && <button className="fleet-action-btn orange" onClick={() => handleRecall(bus)}><RotateCcw size={14} /> Recall</button>}
                      <button className="fleet-action-btn red" onClick={() => handleDelete(bus)}><X size={14} /> Delete</button>
                    </div></td>
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
          : <div className="standby-grid">
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
        }
      </div>
    </div>
  );
}
