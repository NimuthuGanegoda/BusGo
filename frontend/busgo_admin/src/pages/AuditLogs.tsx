import { useState, useEffect, useCallback } from 'react';
import { Download, Calendar, RefreshCw } from 'lucide-react';
import './AuditLogs.css';

const API   = 'http://localhost:5000/api/admin';
const token = () => localStorage.getItem('busgo_access_token') ?? '';

const actionStyles: Record<string, { bg: string; color: string; label: string }> = {
  UPDATE_ALERT_STATUS: { bg: '#ecfdf5', color: '#16a34a', label: '✓ RESOLVE ALERT' },
  DEACTIVATE_USER:     { bg: '#fef2f2', color: '#e74c3c', label: '✕ DEACTIVATE' },
  REACTIVATE_USER:     { bg: '#ecfdf5', color: '#16a34a', label: '✓ ACTIVATE' },
  UPDATE_USER:         { bg: '#ebf3ff', color: '#1a6cf0', label: '→ UPDATE USER' },
  CREATE_BUS:          { bg: '#ecfdf5', color: '#16a34a', label: '+ CREATE BUS' },
  UPDATE_BUS:          { bg: '#ebf3ff', color: '#1a6cf0', label: '→ UPDATE BUS' },
  DELETE_BUS:          { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE BUS' },
  DEPLOY_STANDBY_BUS:  { bg: '#ecfdf5', color: '#16a34a', label: '→ DEPLOY BUS' },
  RECALL_BUS:          { bg: '#fffbeb', color: '#d97706', label: '↩ RECALL BUS' },
  CREATE_ROUTE:        { bg: '#ecfdf5', color: '#16a34a', label: '+ CREATE ROUTE' },
  UPDATE_ROUTE:        { bg: '#ebf3ff', color: '#1a6cf0', label: '→ UPDATE ROUTE' },
  DELETE_ROUTE:        { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE ROUTE' },
};

const getStyle = (action: string) =>
  actionStyles[action] ?? { bg: '#f3f4f6', color: '#6b7280', label: action };

type LogEntry = {
  id: string;
  action: string;
  table_name: string;
  record_id: string;
  metadata: Record<string, any>;
  created_at: string;
  users: { id: string; full_name: string; email: string } | null;
};

export default function AuditLogs() {
  const [logs,         setLogs]         = useState<LogEntry[]>([]);
  const [loading,      setLoading]      = useState(true);
  const [actionFilter, setActionFilter] = useState('all');
  const [currentPage,  setCurrentPage]  = useState(1);
  const [total,        setTotal]        = useState(0);
  const PAGE_SIZE = 20;

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

  useEffect(() => { fetchLogs(); }, [fetchLogs]);

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  const exportCSV = () => {
    const rows = [
      ['Timestamp', 'Admin', 'Email', 'Action', 'Table', 'Record ID', 'Details'],
      ...logs.map(l => [
        new Date(l.created_at).toLocaleString(),
        l.users?.full_name || '—',
        l.users?.email || '—',
        l.action,
        l.table_name,
        l.record_id,
        JSON.stringify(l.metadata),
      ]),
    ];
    const csv  = rows.map(r => r.map(c => `"${c}"`).join(',')).join('\n');
    const blob = new Blob([csv], { type: 'text/csv' });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement('a');
    a.href = url; a.download = `audit-logs-${Date.now()}.csv`; a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="audit-page">
      <div className="audit-header">
        <h1>Audit Logs</h1>
        <div className="audit-filters">
          <select value={actionFilter} onChange={e => { setActionFilter(e.target.value); setCurrentPage(1); }} className="audit-filter">
            <option value="all">All Actions</option>
            <option value="UPDATE_ALERT_STATUS">Resolve Alert</option>
            <option value="DEACTIVATE_USER">Deactivate User</option>
            <option value="REACTIVATE_USER">Activate User</option>
            <option value="UPDATE_USER">Update User</option>
            <option value="CREATE_BUS">Create Bus</option>
            <option value="UPDATE_BUS">Update Bus</option>
            <option value="DELETE_BUS">Delete Bus</option>
            <option value="DEPLOY_STANDBY_BUS">Deploy Bus</option>
            <option value="RECALL_BUS">Recall Bus</option>
          </select>
          <button className="audit-export-btn" onClick={fetchLogs} style={{ marginRight: '8px' }}>
            <RefreshCw size={16} /> Refresh
          </button>
          <button className="audit-export-btn" onClick={exportCSV}>
            <Download size={16} /> Export CSV
          </button>
        </div>
      </div>

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
        <span className="pagination-info">
          Showing {logs.length} of {total} log entries
        </span>
        <div className="pagination-controls">
          <button className="page-btn" disabled={currentPage === 1}
            onClick={() => setCurrentPage(p => p - 1)}>←</button>
          {Array.from({ length: Math.min(totalPages, 5) }, (_, i) => i + 1).map(p => (
            <button key={p} className={`page-btn ${p === currentPage ? 'active' : ''}`}
              onClick={() => setCurrentPage(p)}>{p}</button>
          ))}
          {totalPages > 5 && <span className="page-dots">...</span>}
          <button className="page-btn" disabled={currentPage === totalPages}
            onClick={() => setCurrentPage(p => p + 1)}>→</button>
        </div>
      </div>
    </div>
  );
}
