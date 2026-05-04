import { useState, useEffect, useCallback } from 'react';
import {
  Plus, Search, Power, Check, X,
  UserPlus, Shield, Users, RefreshCw,
  FileImage, Phone, Mail, Calendar, Eye, MapPin,
} from 'lucide-react';
import './UserManagement.css';

const API   = 'http://localhost:5000/api/admin';
const token = () => localStorage.getItem('busgo_access_token') ?? '';

type User = {
  id: string;
  email: string;
  full_name: string;
  username: string | null;
  phone: string | null;
  role: 'passenger' | 'driver' | 'admin';
  is_active: boolean;
  membership_type: string;
  license_url: string | null;
  experience_areas?: string[];
  created_at: string;
};

type Tab = 'passengers' | 'drivers' | 'admins';

export default function UserManagement() {
  const [activeTab,      setActiveTab]      = useState<Tab>('drivers');
  const [users,          setUsers]          = useState<User[]>([]);
  const [loading,        setLoading]        = useState(true);
  const [searchQuery,    setSearchQuery]    = useState('');
  const [statusFilter,   setStatusFilter]   = useState('all');
  const [toast,          setToast]          = useState('');
  const [toastType,      setToastType]      = useState<'success' | 'error'>('success');
  const [selectedDriver, setSelectedDriver] = useState<User | null>(null);
  const [licenseUrl,     setLicenseUrl]     = useState<string | null>(null);
  const [licenseLoading, setLicenseLoading] = useState(false);

  const [showAddModal, setShowAddModal] = useState(false);
  const [addForm,      setAddForm]      = useState({
    full_name: '', email: '', phone: '', password: '',
    role: 'driver' as 'driver' | 'passenger' | 'admin',
  });
  const [addLoading, setAddLoading] = useState(false);
  const [addError,   setAddError]   = useState('');

  const showToast = (msg: string, type: 'success' | 'error' = 'success') => {
    setToast(msg); setToastType(type);
    setTimeout(() => setToast(''), 4000);
  };

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    try {
      const roleMap: Record<Tab, string> = {
        drivers: 'driver', passengers: 'passenger', admins: 'admin',
      };
      const res  = await fetch(`${API}/users?role=${roleMap[activeTab]}&page_size=100`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      setUsers(Array.isArray(json.data) ? json.data : []);
    } catch (e) {
      console.error('[UserManagement] Fetch error:', e);
    } finally {
      setLoading(false);
    }
  }, [activeTab]);

  useEffect(() => { fetchUsers(); }, [fetchUsers]);

  const openDriverPanel = async (user: User) => {
    setSelectedDriver(user);
    setLicenseUrl(null);
    if (!user.license_url) return;
    setLicenseLoading(true);
    try {
      const res  = await fetch(`${API}/users/${user.id}/license-url`, {
        headers: { Authorization: `Bearer ${token()}` },
      });
      const json = await res.json();
      if (res.ok && json.data?.signed_url) setLicenseUrl(json.data.signed_url);
    } catch (e) {
      console.error('[License]', e);
    } finally {
      setLicenseLoading(false);
    }
  };

  const closePanel = () => { setSelectedDriver(null); setLicenseUrl(null); };

  const filtered = users.filter(u => {
    const q           = searchQuery.toLowerCase();
    const matchSearch = !q ||
      u.full_name?.toLowerCase().includes(q) ||
      u.email?.toLowerCase().includes(q) ||
      u.id?.toLowerCase().includes(q);
    if (statusFilter === 'pending')  return matchSearch && !u.is_active && u.role === 'driver';
    if (statusFilter === 'active')   return matchSearch && u.is_active;
    if (statusFilter === 'inactive') return matchSearch && !u.is_active;
    return matchSearch;
  });

  const pendingCount = users.filter(u => u.role === 'driver' && !u.is_active).length;

  const approveDriver = async (id: string) => {
    try {
      const res = await fetch(`${API}/users/${id}/reactivate`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${token()}` },
      });
      if (!res.ok) throw new Error();
      setUsers(prev => prev.map(u => u.id === id ? { ...u, is_active: true } : u));
      if (selectedDriver?.id === id) setSelectedDriver(prev => prev ? { ...prev, is_active: true } : null);
      showToast('✅ Driver approved — they can now log in');
    } catch { showToast('❌ Failed to approve driver', 'error'); }
  };

  const rejectDriver = async (id: string) => {
    try {
      await fetch(`${API}/users/${id}`, {
        method: 'DELETE', headers: { Authorization: `Bearer ${token()}` },
      });
      setUsers(prev => prev.filter(u => u.id !== id));
      closePanel();
      showToast('Driver application rejected');
    } catch { showToast('❌ Failed to reject driver', 'error'); }
  };

  const deactivateUser = async (id: string) => {
    try {
      const res = await fetch(`${API}/users/${id}/deactivate`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${token()}` },
      });
      if (!res.ok) throw new Error();
      setUsers(prev => prev.map(u => u.id === id ? { ...u, is_active: false } : u));
      showToast('User deactivated');
    } catch { showToast('❌ Failed to deactivate user', 'error'); }
  };

  const reactivateUser = async (id: string) => {
    try {
      const res = await fetch(`${API}/users/${id}/reactivate`, {
        method: 'PATCH', headers: { Authorization: `Bearer ${token()}` },
      });
      if (!res.ok) throw new Error();
      setUsers(prev => prev.map(u => u.id === id ? { ...u, is_active: true } : u));
      showToast('User activated');
    } catch { showToast('❌ Failed to activate user', 'error'); }
  };

  const handleAddUser = async () => {
    if (!addForm.full_name || !addForm.email || !addForm.password) {
      setAddError('Full name, email and password are required'); return;
    }
    setAddLoading(true); setAddError('');
    try {
      const res  = await fetch(`http://localhost:5000/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token()}` },
        body: JSON.stringify({
          full_name: addForm.full_name, email: addForm.email.toLowerCase(),
          phone: addForm.phone || undefined, password: addForm.password,
          role: addForm.role, membership_type: 'standard',
        }),
      });
      const json = await res.json();
      if (!res.ok) { setAddError(json.message || 'Failed to create user'); return; }
      if (addForm.role === 'driver' && json.data?.user?.id) {
        await fetch(`${API}/users/${json.data.user.id}/reactivate`, {
          method: 'PATCH', headers: { Authorization: `Bearer ${token()}` },
        });
      }
      setShowAddModal(false);
      setAddForm({ full_name: '', email: '', phone: '', password: '', role: 'driver' });
      showToast(`✅ ${addForm.role.charAt(0).toUpperCase() + addForm.role.slice(1)} created`);
      fetchUsers();
    } catch { setAddError('Connection failed'); }
    finally { setAddLoading(false); }
  };

  const getStatusLabel = (u: User) => {
    if (u.role === 'driver' && !u.is_active) return 'pending';
    return u.is_active ? 'active' : 'inactive';
  };
  const getStatusText = (u: User) => {
    if (u.role === 'driver' && !u.is_active) return 'Pending';
    return u.is_active ? 'Active' : 'Inactive';
  };

  return (
    <div className="users-page">
      {toast && (
        <div className="users-toast"
          style={{ background: toastType === 'error' ? '#dc2626' : '#16a34a' }}>
          {toastType === 'success' ? <Check size={16} /> : <X size={16} />}
          <span>{toast}</span>
          <button onClick={() => setToast('')}><X size={14} /></button>
        </div>
      )}

      {showAddModal && (
        <div className="em-modal-overlay" onClick={() => setShowAddModal(false)}>
          <div className="em-modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '440px' }}>
            <div className="em-modal-header">
              <h3>Add New User</h3>
              <button className="em-modal-close" onClick={() => setShowAddModal(false)}><X size={20} /></button>
            </div>
            <div className="em-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {addError && (
                <div style={{ background: '#fef2f2', border: '1px solid #fca5a5',
                  borderRadius: '8px', padding: '10px 14px', color: '#dc2626', fontSize: '13px' }}>
                  {addError}
                </div>
              )}
              <div>
                <label style={{ fontSize: '11px', fontWeight: 700, color: '#6b7280', letterSpacing: '0.5px' }}>ROLE</label>
                <select value={addForm.role}
                  onChange={e => setAddForm(f => ({ ...f, role: e.target.value as any }))}
                  style={{ width: '100%', marginTop: '6px', padding: '10px 12px',
                    border: '1px solid #e2e6ed', borderRadius: '8px', fontSize: '14px' }}>
                  <option value="driver">Driver</option>
                  <option value="passenger">Passenger</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              {(['full_name', 'email', 'phone', 'password'] as const).map(field => (
                <div key={field}>
                  <label style={{ fontSize: '11px', fontWeight: 700, color: '#6b7280', letterSpacing: '0.5px' }}>
                    {field.replace('_', ' ').toUpperCase()}{field === 'phone' ? ' (optional)' : ''}
                  </label>
                  <input
                    type={field === 'password' ? 'password' : field === 'email' ? 'email' : 'text'}
                    value={addForm[field]}
                    onChange={e => setAddForm(f => ({ ...f, [field]: e.target.value }))}
                    placeholder={field === 'full_name' ? 'Nimal Perera'
                      : field === 'email' ? 'user@example.com'
                      : field === 'phone' ? '+94 77 123 4567' : '••••••••'}
                    style={{ width: '100%', marginTop: '6px', padding: '10px 12px',
                      border: '1px solid #e2e6ed', borderRadius: '8px',
                      fontSize: '14px', boxSizing: 'border-box' }}
                  />
                </div>
              ))}
              <button onClick={handleAddUser} disabled={addLoading}
                style={{ marginTop: '8px', padding: '12px', background: '#1a6cf0',
                  color: '#fff', border: 'none', borderRadius: '8px',
                  fontSize: '14px', fontWeight: 700, cursor: 'pointer' }}>
                {addLoading ? 'Creating...' : 'Create User'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="users-header">
        <h1>User Management</h1>
        <div className="users-header-actions">
          <button className="users-btn primary" onClick={() => setShowAddModal(true)}>
            <Plus size={16} /> Add User
          </button>
          <button className="users-btn outline" onClick={fetchUsers}>
            <RefreshCw size={16} /> Refresh
          </button>
        </div>
      </div>

      <div className="users-tabs">
        <button className={`users-tab ${activeTab === 'passengers' ? 'active' : ''}`}
          onClick={() => { setActiveTab('passengers'); setSearchQuery(''); setStatusFilter('all'); closePanel(); }}>
          <Users size={16} /> Passengers
          <span className="tab-count">{activeTab === 'passengers' ? users.length : '—'}</span>
        </button>
        <button className={`users-tab ${activeTab === 'drivers' ? 'active' : ''}`}
          onClick={() => { setActiveTab('drivers'); setSearchQuery(''); setStatusFilter('all'); closePanel(); }}>
          <UserPlus size={16} /> Drivers
          {pendingCount > 0 && <span className="tab-badge">{pendingCount}</span>}
        </button>
        <button className={`users-tab ${activeTab === 'admins' ? 'active' : ''}`}
          onClick={() => { setActiveTab('admins'); setSearchQuery(''); setStatusFilter('all'); closePanel(); }}>
          <Shield size={16} /> Admins
          <span className="tab-count">{activeTab === 'admins' ? users.length : '—'}</span>
        </button>
      </div>

      <div className="users-filters">
        <div className="users-search-wrap">
          <Search size={16} className="search-icon" />
          <input type="text" placeholder={`Search ${activeTab}...`}
            value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
            className="users-search" />
        </div>
        <select value={statusFilter}
          onChange={e => setStatusFilter(e.target.value)} className="users-filter">
          <option value="all">All Status</option>
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
          {activeTab === 'drivers' && <option value="pending">Pending Approval</option>}
        </select>
        <span className="users-showing">Showing {filtered.length} of {users.length} {activeTab}</span>
      </div>

      <div style={{ display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px', color: '#6b7280' }}>Loading {activeTab}...</div>
          ) : (
            <div className="users-table-wrap">
              <table className="users-table">
                <thead>
                  <tr>
                    <th>NAME</th><th>EMAIL</th><th>PHONE</th>
                    <th>JOINED</th><th>STATUS</th><th>ACTIONS</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.map(user => {
                    const statusLabel = getStatusLabel(user);
                    const isPending   = user.role === 'driver' && !user.is_active;
                    const isSelected  = selectedDriver?.id === user.id;
                    return (
                      <tr key={user.id}
                        style={{ background: isSelected ? '#eff6ff' : undefined, cursor: 'pointer' }}
                        onClick={() => openDriverPanel(user)}>
                        <td>
                          <div className="driver-name-cell">
                            <span className="driver-name">{user.full_name || '—'}</span>
                            <span style={{ fontFamily: 'monospace', fontSize: '11px', color: '#9ca3af' }}>
                              {user.id.slice(0, 8)}…
                            </span>
                          </div>
                        </td>
                        <td className="driver-email">{user.email}</td>
                        <td>{user.phone || '—'}</td>
                        <td style={{ fontSize: '12px', color: '#9ca3af' }}>
                          {new Date(user.created_at).toLocaleDateString()}
                        </td>
                        <td>
                          <span className={`user-status-badge ${statusLabel}`}>
                            <span className="status-dot-sm"></span>
                            {getStatusText(user)}
                          </span>
                        </td>
                        <td onClick={e => e.stopPropagation()}>
                          <div className="user-action-btns">
                            {isPending ? (
                              <>
                                <button className="user-action-btn green" onClick={() => approveDriver(user.id)}>
                                  <Check size={14} /> Approve
                                </button>
                                <button className="user-action-btn red-outline" onClick={() => rejectDriver(user.id)}>
                                  <X size={14} /> Reject
                                </button>
                              </>
                            ) : (
                              user.is_active ? (
                                <button className="user-action-btn gray" onClick={() => deactivateUser(user.id)}>
                                  <Power size={14} /> Deactivate
                                </button>
                              ) : (
                                <button className="user-action-btn green" onClick={() => reactivateUser(user.id)}>
                                  <Check size={14} /> Activate
                                </button>
                              )
                            )}
                            <button className="user-action-btn blue" onClick={() => openDriverPanel(user)}>
                              <Eye size={14} /> View
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {filtered.length === 0 && (
                    <tr>
                      <td colSpan={6} className="empty-row">
                        {activeTab === 'drivers' && statusFilter === 'pending'
                          ? '✓ No pending driver applications'
                          : `No ${activeTab} found`}
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </div>

        {/* ── Driver Detail Side Panel ─────────────────────────────────────── */}
        {selectedDriver && (
          <div style={{
            width: '340px', flexShrink: 0, background: '#fff',
            borderRadius: '16px', border: '1px solid #e5e7eb',
            boxShadow: '0 4px 24px rgba(0,0,0,0.08)', overflow: 'hidden',
          }}>
            {/* Header */}
            <div style={{
              background: selectedDriver.is_active
                ? 'linear-gradient(135deg, #0a2342, #1565c0)'
                : 'linear-gradient(135deg, #78350f, #d97706)',
              padding: '20px', color: '#fff',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <div style={{ fontSize: '11px', fontWeight: 700, letterSpacing: '1px', opacity: 0.8, marginBottom: '6px' }}>
                    {selectedDriver.role === 'driver' && !selectedDriver.is_active
                      ? '⏳ PENDING APPROVAL' : selectedDriver.role === 'driver' ? '👤 DRIVER PROFILE' : '👤 USER PROFILE'}
                  </div>
                  <div style={{ fontSize: '18px', fontWeight: 800 }}>{selectedDriver.full_name}</div>
                  <div style={{ fontSize: '12px', opacity: 0.8, marginTop: '4px' }}>{selectedDriver.email}</div>
                </div>
                <button onClick={closePanel} style={{
                  background: 'rgba(255,255,255,0.2)', border: 'none',
                  borderRadius: '8px', padding: '6px', cursor: 'pointer', color: '#fff',
                }}>
                  <X size={16} />
                </button>
              </div>
            </div>

            {/* Details */}
            <div style={{ padding: '16px', borderBottom: '1px solid #f3f4f6' }}>
              {[
                { icon: <Mail size={14} />,     label: 'Email',  value: selectedDriver.email },
                { icon: <Phone size={14} />,    label: 'Phone',  value: selectedDriver.phone || '—' },
                { icon: <Calendar size={14} />, label: 'Joined', value: new Date(selectedDriver.created_at).toLocaleDateString('en-LK') },
                { icon: <Shield size={14} />,   label: 'Role',   value: selectedDriver.role },
              ].map(({ icon, label, value }) => (
                <div key={label} style={{
                  display: 'flex', alignItems: 'center', gap: '10px',
                  padding: '8px 0', borderBottom: '1px solid #f9fafb',
                }}>
                  <div style={{ color: '#6b7280', width: '16px' }}>{icon}</div>
                  <span style={{ fontSize: '11px', color: '#9ca3af', width: '52px' }}>{label}</span>
                  <span style={{ fontSize: '13px', fontWeight: 600, color: '#1f2937' }}>{value}</span>
                </div>
              ))}
            </div>

            {/* ── Experience Areas ─────────────────────────────────────────── */}
            {selectedDriver.role === 'driver' && (
              <div style={{ padding: '16px', borderBottom: '1px solid #f3f4f6' }}>
                <div style={{
                  fontSize: '11px', fontWeight: 700, color: '#6b7280',
                  letterSpacing: '0.8px', marginBottom: '10px',
                  display: 'flex', alignItems: 'center', gap: '6px',
                }}>
                  <MapPin size={14} /> ROUTE EXPERIENCE AREAS
                </div>
                {selectedDriver.experience_areas && selectedDriver.experience_areas.length > 0 ? (
                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                    {selectedDriver.experience_areas.map((area: string) => (
                      <span key={area} style={{
                        background: '#eff6ff', color: '#1d4ed8',
                        border: '1px solid #bfdbfe',
                        padding: '3px 10px', borderRadius: '12px',
                        fontSize: '12px', fontWeight: 600,
                      }}>
                        📍 {area}
                      </span>
                    ))}
                  </div>
                ) : (
                  <div style={{
                    background: '#f9fafb', borderRadius: '8px',
                    padding: '10px 14px', fontSize: '13px', color: '#9ca3af',
                  }}>
                    No experience areas specified
                  </div>
                )}
              </div>
            )}

            {/* License */}
            {selectedDriver.role === 'driver' && (
              <div style={{ padding: '16px', borderBottom: '1px solid #f3f4f6' }}>
                <div style={{
                  fontSize: '11px', fontWeight: 700, color: '#6b7280',
                  letterSpacing: '0.8px', marginBottom: '10px',
                  display: 'flex', alignItems: 'center', gap: '6px',
                }}>
                  <FileImage size={14} /> DRIVER'S LICENSE
                </div>
                {!selectedDriver.license_url ? (
                  <div style={{ background: '#fef2f2', border: '1px solid #fecaca',
                    borderRadius: '10px', padding: '20px', textAlign: 'center' }}>
                    <FileImage size={24} style={{ color: '#f87171', margin: '0 auto 8px' }} />
                    <div style={{ fontSize: '13px', color: '#dc2626', fontWeight: 600 }}>No license uploaded</div>
                  </div>
                ) : licenseLoading ? (
                  <div style={{ background: '#f9fafb', borderRadius: '10px', padding: '40px',
                    textAlign: 'center', color: '#6b7280', fontSize: '13px' }}>
                    Loading license image...
                  </div>
                ) : licenseUrl ? (
                  <div>
                    <img src={licenseUrl} alt="Driver License" style={{
                      width: '100%', borderRadius: '10px', border: '1px solid #e5e7eb',
                      objectFit: 'cover', maxHeight: '200px',
                    }} />
                    <a href={licenseUrl} target="_blank" rel="noopener noreferrer"
                      style={{ display: 'block', textAlign: 'center', marginTop: '8px',
                        fontSize: '12px', color: '#1a6cf0', textDecoration: 'none', fontWeight: 600 }}>
                      Open full image ↗
                    </a>
                  </div>
                ) : (
                  <div style={{ background: '#fef2f2', borderRadius: '10px', padding: '20px',
                    textAlign: 'center', fontSize: '13px', color: '#dc2626' }}>
                    Failed to load license image
                  </div>
                )}
              </div>
            )}

            {/* Approve / Reject */}
            {selectedDriver.role === 'driver' && !selectedDriver.is_active && (
              <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <div style={{ fontSize: '11px', fontWeight: 700, color: '#6b7280',
                  letterSpacing: '0.8px', marginBottom: '2px' }}>APPROVAL DECISION</div>
                <button onClick={() => approveDriver(selectedDriver.id)}
                  style={{ width: '100%', padding: '12px', background: '#16a34a', color: '#fff',
                    border: 'none', borderRadius: '10px', fontSize: '14px', fontWeight: 700,
                    cursor: 'pointer', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', gap: '8px' }}>
                  <Check size={16} /> Approve Driver
                </button>
                <button onClick={() => rejectDriver(selectedDriver.id)}
                  style={{ width: '100%', padding: '12px', background: '#fff', color: '#dc2626',
                    border: '2px solid #dc2626', borderRadius: '10px', fontSize: '14px',
                    fontWeight: 700, cursor: 'pointer', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', gap: '8px' }}>
                  <X size={16} /> Reject Application
                </button>
              </div>
            )}

            {selectedDriver.is_active && (
              <div style={{ padding: '16px' }}>
                <button onClick={() => deactivateUser(selectedDriver.id)}
                  style={{ width: '100%', padding: '12px', background: '#fff', color: '#6b7280',
                    border: '1px solid #e5e7eb', borderRadius: '10px', fontSize: '14px',
                    fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', gap: '8px' }}>
                  <Power size={16} /> Deactivate Driver
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
