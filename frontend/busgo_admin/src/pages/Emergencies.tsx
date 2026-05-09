import { useState, useEffect, useCallback, useRef } from 'react';
import { createPortal } from 'react-dom';
import { CheckCircle, Eye, RefreshCw, X } from 'lucide-react';
import './Emergencies.css';

const PRIORITY_COLORS: Record<number, string> = {
  5: '#ef4444',
  4: '#f59e0b',
  3: '#3b82f6',
  2: '#22c55e',
  1: '#6b7280',
};

const PRIORITY_LABELS: Record<number, string> = {
  5: 'P5 • CRITICAL',
  4: 'P4 • HIGH',
  3: 'P3 • MEDIUM',
  2: 'P2 • LOW',
  1: 'P1 • FALSE',
};

const STATUS_CONFIG: Record<string, { label: string; color: string; bg: string }> = {
  pending:      { label: 'Pending',      color: '#ef4444', bg: 'rgba(239,68,68,0.1)' },
  acknowledged: { label: 'Acknowledged', color: '#3b82f6', bg: 'rgba(59,130,246,0.1)' },
  resolved:     { label: 'Resolved',     color: '#6b7280', bg: 'rgba(107,114,128,0.08)' },
};

const TYPE_ICONS: Record<string, string> = {
  medical:    '🥺',
  criminal:   '🚨',
  breakdown:  '🔧',
  harassment: '⚠️',
  other:      '📋',
};

const ADMIN_API = 'https://busgo-production.up.railway.app/api/admin';
const PAGE_SIZE = 10;

export default function Emergencies() {
  const [alerts,       setAlerts]       = useState<any[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter,   setTypeFilter]   = useState('all');
  const [toast,        setToast]        = useState('');
  const [detail,       setDetail]       = useState<any>(null);
  const [lastUpdated,  setLastUpdated]  = useState<Date | null>(null);
  const [currentPage,  setCurrentPage]  = useState(1);
  const [total,        setTotal]        = useState(0);

  const prevCountRef = useRef(0);
  const pollRef      = useRef<ReturnType<typeof setInterval> | null>(null);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(''), 4000);
  };

  const fetchAlerts = useCallback(async (silent = false) => {
    if (!silent) setLoading(true);
    try {
      const params = new URLSearchParams({
        page:      String(currentPage),
        page_size: String(PAGE_SIZE),
      });
      if (statusFilter !== 'all') params.set('status', statusFilter);
      if (typeFilter   !== 'all') params.set('alert_type', typeFilter);

      const res = await fetch(`${ADMIN_API}/emergency?${params}`, {
        headers: { Authorization: `Bearer ${localStorage.getItem('busgo_access_token')}` },
      });

      if (!res.ok) {
        console.error('[Emergencies] HTTP error:', res.status);
        return;
      }

      const json = await res.json();

      // Backend returns { data: { alerts: [...], pagination: {...} } }
      const found: any[]   = json.data?.alerts ?? (Array.isArray(json.data) ? json.data : []);
      const pagination     = json.data?.pagination ?? json.pagination ?? null;
      const totalCount     = pagination?.total ?? found.length;

      if (silent && found.length > prevCountRef.current) {
        const newCount = found.length - prevCountRef.current;
        showToast(`🚨 ${newCount} new emergency alert${newCount > 1 ? 's' : ''} received`);
      }
      prevCountRef.current = found.length;

      setAlerts(found);
      setTotal(totalCount);
      setLastUpdated(new Date());
    } catch (e) {
      console.error('[Emergencies] Fetch error:', e);
    } finally {
      if (!silent) setLoading(false);
    }
  }, [statusFilter, typeFilter, currentPage]);

  useEffect(() => { fetchAlerts(); }, [fetchAlerts]);

  useEffect(() => {
    pollRef.current = setInterval(() => fetchAlerts(true), 20_000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [fetchAlerts]);

  // Reset to page 1 when filters change
  useEffect(() => { setCurrentPage(1); }, [statusFilter, typeFilter]);

  const updateStatus = async (id: string, status: string) => {
    try {
      const res = await fetch(`${ADMIN_API}/emergency/${id}/status`, {
        method:  'PATCH',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${localStorage.getItem('busgo_access_token')}`,
        },
        body: JSON.stringify({ status }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setAlerts(prev => prev.map(a => a.id === id ? { ...a, status } : a));
      showToast(`✅ Alert marked as ${status}`);
    } catch (e) {
      console.error('[Emergencies] Status update failed:', e);
      showToast('❌ Failed to update alert status');
    }
  };

  const openDetail = (e: React.MouseEvent, alert: any) => {
    e.stopPropagation();
    e.preventDefault();
    setDetail(alert);
  };

  const totals = {
    all:          total,
    pending:      alerts.filter(a => a.status === 'pending').length,
    acknowledged: alerts.filter(a => a.status === 'acknowledged').length,
    resolved:     alerts.filter(a => a.status === 'resolved').length,
  };

  // ── Detail Modal rendered via Portal directly into document.body ──────────
  const detailModal = detail ? createPortal(
    <div
      style={{
        position: 'fixed', inset: 0,
        background: 'rgba(0,0,0,0.5)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        zIndex: 999999,
      }}
      onClick={() => setDetail(null)}
    >
      <div
        style={{
          background: '#fff', borderRadius: '16px',
          width: '100%', maxWidth: '520px',
          boxShadow: '0 20px 60px rgba(0,0,0,0.2)',
          maxHeight: '90vh', overflowY: 'auto',
        }}
        onClick={e => e.stopPropagation()}
      >
        {/* Modal Header */}
        <div style={{
          display: 'flex', alignItems: 'center',
          justifyContent: 'space-between',
          padding: '20px 24px',
          borderBottom: '1px solid #f0f2f5',
          position: 'sticky', top: 0, background: '#fff',
          borderRadius: '16px 16px 0 0',
        }}>
          <h3 style={{ fontSize: '18px', fontWeight: 700, color: '#111827', margin: 0 }}>
            Alert Details
          </h3>
          <button
            onClick={() => setDetail(null)}
            style={{
              background: 'none', border: 'none',
              color: '#9ca3af', cursor: 'pointer',
              padding: '4px', borderRadius: '6px',
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Modal Body */}
        <div style={{ padding: '20px 24px 28px' }}>
          {[
            ['Alert ID',     detail.id],
            ['Type',         detail.alert_type?.toUpperCase()],
            ['ML Priority',  detail.ml_priority ? PRIORITY_LABELS[detail.ml_priority] : '—'],
            ['ML Action',    detail.ml_action || '—'],
            ['False Alert?', detail.ml_is_false ? '⚠️ YES' : 'No'],
            ['Confidence',   detail.ml_confidence ? `${(detail.ml_confidence * 100).toFixed(0)}%` : '—'],
            ['Description',  detail.description || '—'],
            ['Reporter',     detail.users?.full_name || '—'],
            ['Role',         detail.users?.role || '—'],
            ['Phone',        detail.users?.phone || '—'],
            ['Bus',          detail.buses?.bus_number || '—'],
            ['Status',       detail.status],
            ['Time',         new Date(detail.created_at).toLocaleString()],
          ].map(([label, value]) => (
            <div key={label} style={{
              display: 'flex', justifyContent: 'space-between',
              padding: '10px 0', borderBottom: '1px solid #f5f7fa',
              fontSize: '14px', color: '#374151',
            }}>
              <span style={{ fontWeight: 600, color: '#6b7280', fontSize: '13px' }}>
                {label}
              </span>
              <span style={{ maxWidth: '60%', textAlign: 'right', wordBreak: 'break-word' }}>
                {value}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>,
    document.body
  ) : null;

  return (
    <div className="emergencies-page">

      {/* Portal modal */}
      {detailModal}

      {/* Toast */}
      {toast && (
        <div className="em-toast">
          <CheckCircle size={16} />
          <span>{toast}</span>
          <button onClick={() => setToast('')}><X size={14} /></button>
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
            <p className="em-subtitle">
              ML-prioritized — P5 Critical shown first
              {lastUpdated && (
                <span style={{ marginLeft: '8px', color: '#9ca3af', fontSize: '11px' }}>
                  · Updated {lastUpdated.toLocaleTimeString()}
                </span>
              )}
            </p>
          </div>
        </div>
        <div className="em-header-right">
          <span className="em-live-badge">
            <span className="em-live-dot"></span>LIVE
          </span>
          <button onClick={() => fetchAlerts()} title="Refresh"
            style={{ background: 'transparent', border: 'none', cursor: 'pointer', marginLeft: '8px' }}>
            <RefreshCw size={18} />
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="em-stats">

        {/* Total Alerts — Bell */}
        <div className="em-stat-card">
          <div className="em-stat-icon total">
            <svg viewBox="0 0 64 64" width="32" height="32" xmlns="http://www.w3.org/2000/svg">
              <path d="M32 6C22.06 6 14 14.06 14 24v16l-4 6h44l-4-6V24C50 14.06 41.94 6 32 6z" fill="#4ECDC4" stroke="#2d3748" strokeWidth="2.5" strokeLinejoin="round"/>
              <ellipse cx="32" cy="52" rx="12" ry="5" fill="#F6C254" stroke="#2d3748" strokeWidth="2"/>
              <circle cx="32" cy="57" r="3.5" fill="white" stroke="#2d3748" strokeWidth="1.5"/>
            </svg>
          </div>
          <div className="em-stat-info">
            <span className="em-stat-value">{totals.all}</span>
            <span className="em-stat-label">Total Alerts</span>
          </div>
        </div>

        {/* Active / New — Emergency Light */}
        <div className="em-stat-card">
          <div className="em-stat-icon critical">
            <svg viewBox="0 0 64 64" width="32" height="32" xmlns="http://www.w3.org/2000/svg">
              <line x1="32" y1="4"  x2="32" y2="12" stroke="#4DA3FF" strokeWidth="4" strokeLinecap="round"/>
              <line x1="10" y1="12" x2="16" y2="18" stroke="#4DA3FF" strokeWidth="4" strokeLinecap="round"/>
              <line x1="54" y1="12" x2="48" y2="18" stroke="#4DA3FF" strokeWidth="4" strokeLinecap="round"/>
              <path d="M12 44 Q12 20 32 20 Q52 20 52 44z" fill="#FFC107"/>
              <rect x="10" y="44" width="44" height="10" rx="5" fill="#3F51B5"/>
            </svg>
          </div>
          <div className="em-stat-info">
            <span className="em-stat-value">{totals.pending}</span>
            <span className="em-stat-label">Active / New</span>
          </div>
        </div>

        {/* Acknowledged — Thumbs Up */}
        <div className="em-stat-card">
          <div className="em-stat-icon responded">
            <svg viewBox="0 0 64 64" width="32" height="32" xmlns="http://www.w3.org/2000/svg">
              <rect x="8" y="30" width="12" height="26" rx="3" fill="#4ECDC4" stroke="#2d3748" strokeWidth="2"/>
              <path d="M20 34 L28 10 Q30 6 34 8 Q38 10 36 18 L34 26 H52 Q56 26 56 30 Q56 34 53 35 Q55 36 54 40 Q53 44 50 44 Q51 47 49 49 Q47 51 44 51 H28 Q24 51 22 49 L20 46z" fill="#F6C254" stroke="#2d3748" strokeWidth="2" strokeLinejoin="round"/>
            </svg>
          </div>
          <div className="em-stat-info">
            <span className="em-stat-value">{totals.acknowledged}</span>
            <span className="em-stat-label">Acknowledged</span>
          </div>
        </div>

        {/* Resolved — Green Tick */}
        <div className="em-stat-card">
          <div className="em-stat-icon resolved">
            <svg viewBox="0 0 64 64" width="32" height="32" xmlns="http://www.w3.org/2000/svg">
              <path d="M32 6 A28 28 0 1 1 58 40" fill="none" stroke="#6b7280" strokeWidth="5" strokeLinecap="round"/>
              <path d="M60 8 L46 24 L38 16" fill="none" stroke="#6b7280" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M16 34 L26 44 L48 22" fill="none" stroke="#22c55e" strokeWidth="5.5" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div className="em-stat-info">
            <span className="em-stat-value">{totals.resolved}</span>
            <span className="em-stat-label">Resolved</span>
          </div>
        </div>

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
            const pri      = alert.ml_priority ?? null;
            const priColor = pri ? PRIORITY_COLORS[pri] : '#9ca3af';
            const priLabel = alert.ml_priority_label || (pri ? PRIORITY_LABELS[pri] : null);
            const status   = STATUS_CONFIG[alert.status] || STATUS_CONFIG.pending;
            const reporter = alert.users?.full_name
              ? `${alert.users.full_name}${alert.users.role ? ` (${alert.users.role})` : ''}`
              : '—';

            return (
              <div key={alert.id} className="em-alert-card"
                style={{ borderLeftColor: priColor }}>
                <div className="em-alert-main">

                  <div style={{ fontSize: '24px', marginRight: '16px' }}>
                    {TYPE_ICONS[alert.alert_type] || '📋'}
                  </div>

                  <div className="em-alert-content">
                    <div className="em-alert-row-top">
                      {priLabel ? (
                        <span style={{
                          color: priColor, background: `${priColor}18`,
                          padding: '2px 8px', borderRadius: '6px',
                          fontSize: '12px', fontWeight: 700, marginRight: '8px',
                        }}>
                          {priLabel}
                        </span>
                      ) : (
                        <span style={{
                          color: '#9ca3af', background: '#f3f4f6',
                          padding: '2px 8px', borderRadius: '6px',
                          fontSize: '12px', fontWeight: 600, marginRight: '8px',
                        }}>
                          Awaiting ML
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
                      <span>👤 {reporter}</span>
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
                          onClick={(e) => {
                            e.stopPropagation();
                            updateStatus(alert.id, 'acknowledged');
                          }}>
                          <Eye size={14} /> Acknowledge
                        </button>
                      )}
                      {alert.status !== 'resolved' && (
                        <button className="em-action-btn success"
                          onClick={(e) => {
                            e.stopPropagation();
                            updateStatus(alert.id, 'resolved');
                          }}>
                          <CheckCircle size={14} /> Resolve
                        </button>
                      )}
                      <button
                        className="em-action-btn secondary"
                        onClick={(e) => openDetail(e, alert)}
                      >
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

      {/* Pagination */}
      {!loading && total > PAGE_SIZE && (
        <div className="audit-pagination" style={{ marginTop: '24px' }}>
          <span className="pagination-info">
            Showing {alerts.length} of {total} alerts
          </span>
          <div className="pagination-controls">
            <button
              className="page-btn"
              disabled={currentPage === 1}
              onClick={() => setCurrentPage(p => p - 1)}
            >←</button>
            {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map(p => (
              <button
                key={p}
                className={`page-btn ${p === currentPage ? 'active' : ''}`}
                onClick={() => setCurrentPage(p)}
              >{p}</button>
            ))}
            {totalPages > 5 && <span className="page-dots">...</span>}
            <button
              className="page-btn"
              disabled={currentPage === totalPages}
              onClick={() => setCurrentPage(p => p + 1)}
            >→</button>
          </div>
        </div>
      )}

    </div>
  );
}