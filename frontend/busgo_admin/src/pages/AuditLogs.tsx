import { useState } from 'react';
import { Download, Calendar } from 'lucide-react';
import { auditLogs } from '../data/mockData';
import './AuditLogs.css';

const actionStyles: Record<string, { bg: string; color: string; label: string }> = {
  RESOLVE: { bg: '#ecfdf5', color: '#16a34a', label: '✓ RESOLVE' },
  UPDATE: { bg: '#ebf3ff', color: '#1a6cf0', label: '→ UPDATE' },
  CREATE: { bg: '#ecfdf5', color: '#16a34a', label: '+ CREATE' },
  DELETE: { bg: '#fef2f2', color: '#e74c3c', label: '✕ DELETE' },
  LOGIN: { bg: '#f3f0ff', color: '#7c3aed', label: '→ LOGIN' },
};

export default function AuditLogs() {
  const [fromDate, setFromDate] = useState('2026-03-18');
  const [toDate, setToDate] = useState('2026-03-18');
  const [adminFilter, setAdminFilter] = useState('all');
  const [actionFilter, setActionFilter] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);

  const totalLogs = 243;

  const filtered = auditLogs.filter((log) => {
    if (actionFilter !== 'all' && log.action !== actionFilter) return false;
    return true;
  });

  return (
    <div className="audit-page">
      <div className="audit-header">
        <h1>Audit Logs</h1>
        <div className="audit-filters">
          <div className="audit-date-filter">
            <Calendar size={14} />
            <span>From:</span>
            <input type="date" value={fromDate} onChange={(e) => setFromDate(e.target.value)} className="audit-date-input" />
          </div>
          <div className="audit-date-filter">
            <Calendar size={14} />
            <span>To:</span>
            <input type="date" value={toDate} onChange={(e) => setToDate(e.target.value)} className="audit-date-input" />
          </div>
          <select value={adminFilter} onChange={(e) => setAdminFilter(e.target.value)} className="audit-filter">
            <option value="all">Admin: All</option>
            <option value="admin@busgo.lk">admin@busgo.lk</option>
          </select>
          <select value={actionFilter} onChange={(e) => setActionFilter(e.target.value)} className="audit-filter">
            <option value="all">Action</option>
            <option value="RESOLVE">Resolve</option>
            <option value="UPDATE">Update</option>
            <option value="CREATE">Create</option>
            <option value="DELETE">Delete</option>
            <option value="LOGIN">Login</option>
          </select>
          <button className="audit-export-btn">
            <Download size={16} /> Export CSV
          </button>
        </div>
      </div>

      <div className="audit-table-wrap">
        <table className="audit-table">
          <thead>
            <tr>
              <th>TIMESTAMP</th>
              <th>ADMIN</th>
              <th>ACTION</th>
              <th>ENTITY</th>
              <th>ENTITY ID</th>
              <th>DETAILS</th>
              <th>IP ADDRESS</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((log) => {
              const style = actionStyles[log.action];
              return (
                <tr key={log.id}>
                  <td className="audit-timestamp">{log.timestamp}</td>
                  <td className="audit-admin">{log.admin}</td>
                  <td>
                    <span
                      className="audit-action-badge"
                      style={{ background: style.bg, color: style.color }}
                    >
                      {style.label}
                    </span>
                  </td>
                  <td>{log.entity}</td>
                  <td className="audit-entity-id">{log.entityId}</td>
                  <td className="audit-details">{log.details}</td>
                  <td className="audit-ip">{log.ipAddress}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="audit-pagination">
        <span className="pagination-info">Showing 1–{filtered.length} of {totalLogs} log entries</span>
        <div className="pagination-controls">
          <button className="page-btn" disabled>←</button>
          {[1, 2, 3].map((p) => (
            <button
              key={p}
              className={`page-btn ${p === currentPage ? 'active' : ''}`}
              onClick={() => setCurrentPage(p)}
            >
              {p}
            </button>
          ))}
          <span className="page-dots">...</span>
          <button className="page-btn" onClick={() => setCurrentPage(35)}>35</button>
          <button className="page-btn">→</button>
        </div>
      </div>
    </div>
  );
}
