import { useState, useEffect, useCallback } from 'react';
import { Download, Calendar, RefreshCw, Shield, FileText } from 'lucide-react';
import './AuditLogs.css';

const API   = 'https://busgo-production.up.railway.app/api/admin';
const token = () => localStorage.getItem('busgo_access_token') ?? '';

// ── Admin action styles ──
const actionStyles: Record<string, { bg: string; color: string; label: string }> = {
  UPDATE_ALERT_STATUS: { bg: '#ecfdf5', color: '#16a34a', label: '✓ RESOLVE ALERT' },
  DEACTIVATE_USER:     { bg: '#fef2f2', color: '#e74c3c', label: '✕ DEACTIVATE' },
  REACTIVATE_USER:     { bg: '#ecfdf5', color: '#16a34a', label: '✓ ACTIVATE' },
  UPDATE_USER:         { bg: '#ebf3ff', color: '#1a6cf0', label: '↻ UPDATE USER' },
  CREATE_BUS:          { bg: '#ecfdf5', color: '#16a34a', label: '+ CREATE BUS' },
  UPDATE_BUS:          { bg: '#ebf3ff', color: '#1a6cf0', label: '↻ UPDATE BUS' },
  DELETE_BUS:          { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE BUS' },
  DELETE_USER:         { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE USER' },
  DEPLOY_STANDBY_BUS:  { bg: '#ecfdf5', color: '#16a34a', label: '↑ DEPLOY BUS' },
  RECALL_BUS:          { bg: '#fffbeb', color: '#d97706', label: '↩ RECALL BUS' },
  CREATE_ROUTE:        { bg: '#ecfdf5', color: '#16a34a', label: '+ CREATE ROUTE' },
  UPDATE_ROUTE:        { bg: '#ebf3ff', color: '#1a6cf0', label: '↻ UPDATE ROUTE' },
  DELETE_ROUTE:        { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE ROUTE' },
};

// ── Security event styles ──
const securityStyles: Record<string, { bg: string; color: string; label: string }> = {
  LOGIN_SUCCESS:    { bg: '#ecfdf5', color: '#16a34a', label: '✓ LOGIN SUCCESS' },
  LOGIN_FAILED:     { bg: '#fef2f2', color: '#e74c3c', label: '✕ LOGIN FAILED' },
  ACCOUNT_LOCKED:   { bg: '#fef2f2', color: '#dc2626', label: '🔒 ACCOUNT LOCKED' },
  ACCOUNT_UNLOCKED: { bg: '#ecfdf5', color: '#16a34a', label: '🔓 UNLOCKED' },
  LOGOUT:           { bg: '#f3f4f6', color: '#6b7280', label: '← LOGOUT' },
  TOKEN_REFRESH:    { bg: '#ebf3ff', color: '#1a6cf0', label: '↻ TOKEN REFRESH' },
  PASSWORD_RESET:   { bg: '#fffbeb', color: '#d97706', label: '🔑 PASSWORD RESET' },
  PASSWORD_CHANGE:  { bg: '#fffbeb', color: '#d97706', label: '🔑 PASSWORD CHANGE' },
  REGISTRATION:     { bg: '#ecfdf5', color: '#16a34a', label: '+ REGISTRATION' },
  ADMIN_ACTION:     { bg: '#ebf3ff', color: '#1a6cf0', label: '⚙ ADMIN ACTION' },
  ROLE_VIOLATION:   { bg: '#fef2f2', color: '#dc2626', label: '⚠ ROLE VIOLATION' },
  RATE_LIMITED:     { bg: '#fffbeb', color: '#d97706', label: '⏱ RATE LIMITED' },
  
};

const severityColors: Record<string, { bg: string; color: string }> = {
  info:     { bg: '#ebf3ff', color: '#1a6cf0' },
  warning:  { bg: '#fffbeb', color: '#d97706' },
  critical: { bg: '#fef2f2', color: '#dc2626' },
};

const getStyle = (action: string) =>
  actionStyles[action] ?? { bg: '#f3f4f6', color: '#6b7280', label: action };

const getSecStyle = (event: string) =>
  securityStyles[event] ?? { bg: '#f3f4f6', color: '#6b7280', label: event };

type LogEntry = {
  id: string;
  action: string;
  table_name: string;
  record_id: string;
  metadata: Record<string, any>;
  created_at: string;
  users: { id: string; full_name: string; email: string } | null;
};

type SecurityEntry = {
  id: string;
  event_type: string;
  user_id: string | null;
  email: string | null;
  ip_address: string | null;
  user_agent: string | null;
  details: Record<string, any>;
  severity: string;
  created_at: string;
};

export default function AuditLogs() {
  // Tab: 0 = Admin Actions, 1 = Security Logs
  const [activeTab, setActiveTab] = useState(0);

  // Admin action logs state
  const [logs,         setLogs]         = useState<LogEntry[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [actionFilter, setActionFilter] = useState('all');
  const [currentPage,  setCurrentPage]  = useState(1);
  const [total,        setTotal]        = useState(0);

  // Security logs state
  const [secLogs,       setSecLogs]       = useState<SecurityEntry[]>([]);
  const [secLoading,    setSecLoading]    = useState(true);
  const [secFilter,     setSecFilter]     = useState('all');
  const [sevFilter,     setSevFilter]     = useState('all');
  const [secPage,       setSecPage]       = useState(1);
  const [secTotal,      setSecTotal]      = useState(0);

  const PAGE_SIZE = 20;

  // ── Fetch admin action logs ──
  const fetchLogs = useCallback(async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        page:      String(currentPage),
        page_size: String(PAGE_SIZE),
      });
      if (actionFilter !== 'all') params.set('action', actionFilter);

      const res  = await fetch(`${API}/audit-logs?${params}`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      setLogs(Array.isArray(json.data) ? json.data : []);
      setTotal(json.pagination?.total ?? 0);
    } catch (e) { console.error('[AuditLogs]', e); }
    finally { setLoading(false); }
  }, [actionFilter, currentPage]);

  // ── Fetch security logs ──
  const fetchSecLogs = useCallback(async () => {
    setSecLoading(true);
    try {
      const params = new URLSearchParams({
        page:      String(secPage),
        page_size: String(PAGE_SIZE),
      });
      if (secFilter !== 'all') params.set('event_type', secFilter);
      if (sevFilter !== 'all') params.set('severity', sevFilter);

      const res = await fetch(`${API}/security-logs?${params}`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      const data = json.data?.data ?? json.data ?? [];
      setSecLogs(Array.isArray(data) ? data : []);
      setSecTotal(json.data?.pagination?.total ?? json.pagination?.total ?? 0);
    } catch (e) { console.error('[SecurityLogs]', e); }
    finally { setSecLoading(false); }
  }, [secFilter, sevFilter, secPage]);

  useEffect(() => { if (activeTab === 0) fetchLogs(); }, [fetchLogs, activeTab]);
  useEffect(() => { if (activeTab === 1) fetchSecLogs(); }, [fetchSecLogs, activeTab]);

  const totalPages    = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const secTotalPages = Math.max(1, Math.ceil(secTotal / PAGE_SIZE));

  // ── Export CSV ──
  const exportCSV = () => {
    if (activeTab === 0) {
      const rows = [
        ['Timestamp', 'Admin', 'Email', 'Action', 'Table', 'Record ID', 'Details'],
        ...logs.map(l => [
          new Date(l.created_at).toLocaleString(),
          l.users?.full_name || '—', l.users?.email || '—',
          l.action, l.table_name, l.record_id, JSON.stringify(l.metadata),
        ]),
      ];
      downloadCSV(rows, 'admin-audit-logs');
    } else {
      const rows = [
        ['Timestamp', 'Event', 'Email', 'IP Address', 'Severity', 'Details'],
        ...secLogs.map(l => [
          new Date(l.created_at).toLocaleString(),
          l.event_type, l.email || '—', l.ip_address || '—',
          l.severity, JSON.stringify(l.details),
        ]),
      ];
      downloadCSV(rows, 'security-logs');
    }
  };

  const downloadCSV = (rows: string[][], filename: string) => {
    const csv  = rows.map(r => r.map(c => `"${c}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url; a.download = `${filename}-${Date.now()}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="audit-page">
      <div className="audit-header">
        <h1>Audit & Security Logs</h1>
        <div className="audit-filters">
          {/* Tab switcher */}
          <div style={{
            display: 'flex', background: '#f3f4f6', borderRadius: '10px',
            padding: '3px', marginRight: '12px',
          }}>
            <button onClick={() => setActiveTab(0)} style={{
              padding: '6px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer',
              fontSize: '12px', fontWeight: 600,
              background: activeTab === 0 ? '#fff' : 'transparent',
              color: activeTab === 0 ? '#1a6cf0' : '#6b7280',
              boxShadow: activeTab === 0 ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
              display: 'flex', alignItems: 'center', gap: '6px',
            }}>
              <FileText size={14} /> Admin Actions
            </button>
            <button onClick={() => setActiveTab(1)} style={{
              padding: '6px 14px', borderRadius: '8px', border: 'none', cursor: 'pointer',
              fontSize: '12px', fontWeight: 600,
              background: activeTab === 1 ? '#fff' : 'transparent',
              color: activeTab === 1 ? '#dc2626' : '#6b7280',
              boxShadow: activeTab === 1 ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
              display: 'flex', alignItems: 'center', gap: '6px',
            }}>
              <Shield size={14} /> Security Logs
            </button>
          </div>

          {/* Filters based on active tab */}
          {activeTab === 0 ? (
            <select value={actionFilter} onChange={e => { setActionFilter(e.target.value); setCurrentPage(1); }} className="audit-filter">
              <option value="all">All Actions</option>
              <option value="UPDATE_ALERT_STATUS">Resolve Alert</option>
              <option value="DEACTIVATE_USER">Deactivate User</option>
              <option value="REACTIVATE_USER">Activate User</option>
              <option value="UPDATE_USER">Update User</option>
              <option value="CREATE_BUS">Create Bus</option>
              <option value="UPDATE_BUS">Update Bus</option>
              <option value="DELETE_BUS">Delete Bus</option>
              <option value="DELETE_USER">Delete User</option>
              <option value="DEPLOY_STANDBY_BUS">Deploy Bus</option>
              <option value="RECALL_BUS">Recall Bus</option>
            </select>
          ) : (
            <>
              <select value={secFilter} onChange={e => { setSecFilter(e.target.value); setSecPage(1); }} className="audit-filter">
                <option value="all">All Events</option>
                <option value="LOGIN_SUCCESS">Login Success</option>
                <option value="LOGIN_FAILED">Login Failed</option>
                <option value="ACCOUNT_LOCKED">Account Locked</option>
                <option value="LOGOUT">Logout</option>
                <option value="REGISTRATION">Registration</option>
                <option value="PASSWORD_RESET">Password Reset</option>
                <option value="ROLE_VIOLATION">Role Violation</option>
              </select>
              <select value={sevFilter} onChange={e => { setSevFilter(e.target.value); setSecPage(1); }} className="audit-filter" style={{ marginLeft: '8px' }}>
                <option value="all">All Severity</option>
                <option value="info">Info</option>
                <option value="warning">Warning</option>
                <option value="critical">Critical</option>
              </select>
            </>
          )}

          <button className="audit-export-btn" onClick={activeTab === 0 ? fetchLogs : fetchSecLogs} style={{ marginRight: '8px', marginLeft: '8px' }}>
            <RefreshCw size={16} /> Refresh
          </button>
          <button className="audit-export-btn" onClick={exportCSV}>
            <Download size={16} /> Export CSV
          </button>
        </div>
      </div>

      {/* ── Admin Actions Table ── */}
      {activeTab === 0 && (
        <>
          <div className="audit-table-wrap">
            {loading ? (
              <div style={{ padding: '40px', textAlign: 'center', color: '#6b7280' }}>Loading audit logs...</div>
            ) : (
              <table className="audit-table">
                <thead>
                  <tr>
                    <th>TIMESTAMP</th>
                    <th>ADMIN</th>
                    <th>ACTION</th>
                    <th>TABLE</th>
                    <th>RECORD ID</th>
                    <th>DETAILS</th>
                  </tr>
                </thead>
                <tbody>
                  {logs.length === 0 && (
                    <tr><td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>No audit logs found</td></tr>
                  )}
                  {logs.map(log => {
                    const style = getStyle(log.action);
                    return (
                      <tr key={log.id}>
                        <td className="audit-timestamp">{new Date(log.created_at).toLocaleString('en-LK', { timeZone: 'Asia/Colombo' })}</td>
                        <td className="audit-admin">
                          <div>{log.users?.full_name || '—'}</div>
                          <div style={{ fontSize: '11px', color: '#9ca3af' }}>{log.users?.email || ''}</div>
                        </td>
                        <td>
                          <span className="audit-action-badge" style={{ background: style.bg, color: style.color }}>
                            {style.label}
                          </span>
                        </td>
                        <td>{log.table_name}</td>
                        <td className="audit-entity-id">{log.record_id?.slice(0, 8)}…</td>
                        <td className="audit-details">
                          {Object.keys(log.metadata || {}).length > 0
                            ? Object.entries(log.metadata).map(([k, v]) => `${k}: ${v}`).join(', ')
                            : '—'}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
          <div className="audit-pagination">
            <span className="pagination-info">Showing {logs.length} of {total} log entries</span>
            <div className="pagination-controls">
              <button className="page-btn" disabled={currentPage === 1} onClick={() => setCurrentPage(p => p - 1)}>←</button>
              {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map(p => (
                <button key={p} className={`page-btn ${p === currentPage ? 'active' : ''}`} onClick={() => setCurrentPage(p)}>{p}</button>
              ))}
              {totalPages > 5 && <span className="page-dots">...</span>}
              <button className="page-btn" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => p + 1)}>→</button>
            </div>
          </div>
        </>
      )}

      {/* ── Security Logs Table ── */}
      {activeTab === 1 && (
        <>
          <div className="audit-table-wrap">
            {secLoading ? (
              <div style={{ padding: '40px', textAlign: 'center', color: '#6b7280' }}>Loading security logs...</div>
            ) : (
              <table className="audit-table">
                <thead>
                  <tr>
                    <th>TIMESTAMP</th>
                    <th>EVENT</th>
                    <th>EMAIL</th>
                    <th>IP ADDRESS</th>
                    <th>SEVERITY</th>
                    <th>DETAILS</th>
                  </tr>
                </thead>
                <tbody>
                  {secLogs.length === 0 && (
                    <tr><td colSpan={6} style={{ textAlign: 'center', padding: '40px', color: '#9ca3af' }}>No security logs found</td></tr>
                  )}
                  {secLogs.map(log => {
                    const style = getSecStyle(log.event_type);
                    const sev   = severityColors[log.severity] ?? severityColors.info;
                    return (
                      <tr key={log.id}>
                        <td className="audit-timestamp">{new Date(log.created_at).toLocaleString('en-LK', { timeZone: 'Asia/Colombo' })}</td>
                        <td>
                          <span className="audit-action-badge" style={{ background: style.bg, color: style.color }}>
                            {style.label}
                          </span>
                        </td>
                        <td className="audit-admin">
                          <div>{log.email || '—'}</div>
                        </td>
                        <td style={{ fontFamily: 'monospace', fontSize: '12px', color: '#6b7280' }}>
                          {log.ip_address || '—'}
                        </td>
                        <td>
                          <span style={{
                            background: sev.bg, color: sev.color,
                            padding: '3px 10px', borderRadius: '6px',
                            fontSize: '11px', fontWeight: 700, textTransform: 'uppercase',
                          }}>
                            {log.severity}
                          </span>
                        </td>
                        <td className="audit-details">
                          {Object.keys(log.details || {}).length > 0
                            ? Object.entries(log.details).map(([k, v]) => `${k}: ${v}`).join(', ')
                            : '—'}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
          <div className="audit-pagination">
            <span className="pagination-info">Showing {secLogs.length} of {secTotal} security events</span>
            <div className="pagination-controls">
              <button className="page-btn" disabled={secPage === 1} onClick={() => setSecPage(p => p - 1)}>←</button>
              {Array.from({ length: Math.min(secTotalPages, 5) }, (_, i) => i + 1).map(p => (
                <button key={p} className={`page-btn ${p === secPage ? 'active' : ''}`} onClick={() => setSecPage(p)}>{p}</button>
              ))}
              {secTotalPages > 5 && <span className="page-dots">...</span>}
              <button className="page-btn" disabled={secPage === secTotalPages} onClick={() => setSecPage(p => p + 1)}>→</button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}






