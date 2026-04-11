import { useState, useEffect, useCallback } from 'react';
import { CheckCircle, Eye, RefreshCw, X } from 'lucide-react';
import './Emergencies.css';

const PRIORITY_COLORS: Record<number, string> = {
  5: '#ef4444', 4: '#f59e0b', 3: '#3b82f6', 2: '#22c55e', 1: '#6b7280',
};

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  pending:      { label: 'Pending',      color: '#ef4444', bg: 'rgba(239,68,68,0.1)' },
  acknowledged: { label: 'Acknowledged', color: '#3b82f6', bg: 'rgba(59,130,246,0.1)' },
  resolved:     { label: 'Resolved',     color: '#6b7280', bg: 'rgba(107,114,128,0.08)' },
};

const TYPE_ICONS: Record<string, string> = {
  medical: '🏥', criminal: '🚨', breakdown: '🔧', harassment: '⚠️', other: '📋',
};

export default function Emergencies() {
  const [alerts,       setAlerts]       = useState<any[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter,   setTypeFilter]   = useState('all');
  const [toast,        setToast]        = useState('');
  const [detail,       setDetail]       = useState<any>(null);

  const token = localStorage.getItem('busgo_access_token');
  

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 4000);
  };

  const fetchAlerts = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page_size: '50' });
      if (statusFilter !== 'all') params.set('status', statusFilter);
      if (typeFilter   !== 'all') params.set('alert_type', typeFilter);

      const res  = await fetch(
        `http://localhost:5000/api/admin/emergency?${params}`,
        { headers: { Authorization: `Bearer ${localStorage.getItem('busgo_access_token')}` } }
      );
      const json = await res.json();
      console.log('Full API response:', JSON.stringify(json));

      // Handle all possible response shapes
      const found: any[] = Array.isArray(json.data) ? json.data : [];
      console.log('Alerts found:', found.length);
      setAlerts(found);
    } catch (e) {
      console.error('Fetch error:', e);
    }
    finally { setLoading(false); }
  }, [statusFilter, typeFilter]);

  useEffect(() => { fetchAlerts(); }, [fetchAlerts]);

  const updateStatus = async (id: string, status: string) => {
    try {
      await fetch(`http://localhost:5000/api/admin/emergency/${id}/status`, {
        method:  'PATCH',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${localStorage.getItem('busgo_access_token')}` },
        body:    JSON.stringify({ status }),
      });
      setAlerts(prev => prev.map(a => a.id === id ? { ...a, status } : a));
      showToast(`Alert ${status}`);
    } catch (e) { console.error(e); }
  };

  const totals = {
    all:          alerts.length,
    pending:      alerts.filter(a => a.status === 'pending').length,
    acknowledged: alerts.filter(a => a.status === 'acknowledged').length,
    resolved:     alerts.filter(a => a.status === 'resolved').length,
  };

  return (
    <div className="emergencies-page">

      {/* Toast */}
      {toast && (
        <div className="em-toast">
          <CheckCircle size={16} />
          <span>{toast}</span>
          <button onClick={() => setToast('')}><X size={14} /></button>
        </div>
      )}

      {/* Detail Modal */}
      {detail && (
        <div className="em-modal-overlay" onClick={() => setDetail(null)}>
          <div className="em-modal" onClick={e => e.stopPropagation()}>
            <div className="em-modal-header">
              <h3>Alert Details</h3>
              <button className="em-modal-close" onClick={() => setDetail(null)}>
                <X size={20} />
              </button>
            </div>
            <div className="em-modal-body">
              {[
                ['Alert ID',     detail.id],
                ['Type',         detail.alert_type?.toUpperCase()],
                ['ML Priority',  detail.ml_priority_label || '—'],
                ['ML Action',    detail.ml_action || '—'],
                ['False Alert?', detail.ml_is_false ? '⚠️ YES' : 'No'],
                ['Confidence',   detail.ml_confidence ? `${(detail.ml_confidence * 100).toFixed(0)}%` : '—'],
                ['Description',  detail.description || '—'],
                ['Reporter',     detail.users?.full_name || '—'],
                ['Phone',        detail.users?.phone || '—'],
                ['Bus',          detail.buses?.bus_number || '—'],
                ['Status',       detail.status],
                ['Time',         new Date(detail.created_at).toLocaleString()],
              ].map(([label, value]) => (
                <div key={label} className="em-modal-row">
                  <span className="em-modal-label">{label}</span>
                  <span>{value}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Header */}
      <div className="em-header">
        <div className="em-header-left">
          <div className="em-header-icon" style={{ background: '#fee2e2', borderRadius: '12px', padding: '10px' }}>
            🚨
          </div>
          <div>
            <h1 className="em-title">Emergency Alerts</h1>
            <p className="em-subtitle">ML-prioritized — most critical shown first</p>
          </div>
        </div>
        <div className="em-header-right">
          <span className="em-live-badge">
            <span className="em-live-dot"></span>LIVE
          </span>
          <button onClick={fetchAlerts}
            style={{ background: 'transparent', border: 'none', cursor: 'pointer', marginLeft: '8px' }}>
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="em-stats">
        {[
          { value: totals.all,          label: 'Total Alerts',  cls: 'total' },
          { value: totals.pending,      label: 'Active / New',  cls: 'critical' },
          { value: totals.acknowledged, label: 'Acknowledged',  cls: 'responded' },
          { value: totals.resolved,     label: 'Resolved',      cls: 'resolved' },
        ].map(s => (
          <div key={s.label} className="em-stat-card">
            <div className={`em-stat-icon ${s.cls}`}></div>
            <div className="em-stat-info">
              <span className="em-stat-value">{s.value}</span>
              <span className="em-stat-label">{s.label}</span>
            </div>
          </div>
        ))}
      </div>

      {/* Filters */}
      <div className="em-filters-bar">
        <div className="em-filters-left">
          <select value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
            className="em-filter-select">
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="acknowledged">Acknowledged</option>
            <option value="resolved">Resolved</option>
          </select>
          <select value={typeFilter}
            onChange={e => setTypeFilter(e.target.value)}
            className="em-filter-select">
            <option value="all">All Types</option>
            <option value="medical">Medical</option>
            <option value="criminal">Criminal</option>
            <option value="breakdown">Breakdown</option>
            <option value="harassment">Harassment</option>
            <option value="other">Other</option>
          </select>
        </div>
      </div>

      {/* Alert List */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>
          Loading alerts...
        </div>
      ) : alerts.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>
          No alerts found ✓
        </div>
      ) : (
        <div className="em-alerts-list">
          {alerts.map(alert => {
            const priColor = PRIORITY_COLORS[alert.ml_priority || 2];
            const status   = STATUS_CONFIG[alert.status] || STATUS_CONFIG.pending;
            return (
              <div key={alert.id} className="em-alert-card"
                style={{ borderLeftColor: priColor }}>
                <div className="em-alert-main">

                  <div className="em-alert-type-icon"
                    style={{ fontSize: '24px', marginRight: '16px' }}>
                    {TYPE_ICONS[alert.alert_type] || '📋'}
                  </div>

                  <div className="em-alert-content">
                    <div className="em-alert-row-top">
                      {alert.ml_priority && (
                        <span style={{
                          color: priColor,
                          background: `${priColor}18`,
                          padding: '2px 8px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 700,
                          marginRight: '8px',
                        }}>
                          {alert.ml_priority_label || `P${alert.ml_priority}`}
                        </span>
                      )}
                      <span className="em-alert-type-label"
                        style={{ color: priColor, fontWeight: 600 }}>
                        {alert.alert_type?.toUpperCase()}
                      </span>
                      {alert.ml_is_false && (
                        <span style={{
                          color: '#6b7280', fontSize: '11px',
                          background: '#f3f4f6', padding: '2px 6px',
                          borderRadius: '4px', marginLeft: '8px',
                        }}>
                          ⚠ Possible False Alert
                        </span>
                      )}
                      <span style={{
                        color: status.color, background: status.bg,
                        padding: '2px 8px', borderRadius: '6px',
                        fontSize: '12px', fontWeight: 600, marginLeft: 'auto',
                      }}>
                        {status.label}
                      </span>
                    </div>

                    <h3 className="em-alert-title">
                      {alert.description || 'No description provided'}
                    </h3>

                    {alert.ml_action && (
                      <div style={{
                        fontSize: '12px', color: priColor,
                        fontWeight: 600, marginBottom: '8px',
                      }}>
                        ⚡ {alert.ml_action}
                      </div>
                    )}

                    <div className="em-alert-meta">
                      <span>👤 {alert.users?.full_name || '—'}</span>
                      {alert.buses?.bus_number && (
                        <><span className="em-alert-meta-divider">|</span>
                        <span>🚌 {alert.buses.bus_number}</span></>
                      )}
                      <span className="em-alert-meta-divider">|</span>
                      <span>🕐 {new Date(alert.created_at).toLocaleTimeString()}</span>
                    </div>

                    <div className="em-alert-actions">
                      {alert.status === 'pending' && (
                        <button className="em-action-btn warning"
                          onClick={() => updateStatus(alert.id, 'acknowledged')}>
                          <Eye size={14} /> Acknowledge
                        </button>
                      )}
                      {alert.status !== 'resolved' && (
                        <button className="em-action-btn success"
                          onClick={() => updateStatus(alert.id, 'resolved')}>
                          <CheckCircle size={14} /> Resolve
                        </button>
                      )}
                      <button className="em-action-btn secondary"
                        onClick={() => setDetail(alert)}>
                        <Eye size={14} /> Details
                      </button>
                    </div>
                  </div>

                  <div className="em-alert-aside">
                    <div className="em-alert-time">
                      {new Date(alert.created_at).toLocaleTimeString()}
                    </div>
                    {alert.ml_confidence && (
                      <div style={{ fontSize: '11px', color: '#6b7280', marginTop: '4px' }}>
                        Conf: {(alert.ml_confidence * 100).toFixed(0)}%
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}