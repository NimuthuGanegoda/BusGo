import { useState } from 'react';
import {
  Plus, Download, Search, Pencil, Power, Trash2, Check, X,
  UserPlus, Shield, Users,
} from 'lucide-react';
import { drivers as initialDrivers, passengers as initialPassengers, admins as initialAdmins } from '../data/mockData';
import type { Driver, Passenger, Admin } from '../types';
import './UserManagement.css';

type Tab = 'passengers' | 'drivers' | 'admins';

export default function UserManagement() {
  const [activeTab, setActiveTab] = useState<Tab>('drivers');
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [routeFilter, setRouteFilter] = useState('all');
  const [sortBy, setSortBy] = useState('name');
  const [currentPage, setCurrentPage] = useState(1);

  // State for each entity
  const [driversList, setDriversList] = useState<Driver[]>(initialDrivers);
  const [passengersList, setPassengersList] = useState<Passenger[]>(initialPassengers);
  const [adminsList, setAdminsList] = useState<Admin[]>(initialAdmins);
  const [toast, setToast] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  };

  const pendingCount = driversList.filter((d) => d.status === 'Pending').length;

  // Driver filters
  const filteredDrivers = driversList.filter((d) => {
    if (statusFilter !== 'all' && d.status !== statusFilter) return false;
    if (searchQuery && !d.name.toLowerCase().includes(searchQuery.toLowerCase()) && !d.id.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  // Passenger filters
  const filteredPassengers = passengersList.filter((p) => {
    if (statusFilter !== 'all' && p.status !== statusFilter) return false;
    if (searchQuery && !p.name.toLowerCase().includes(searchQuery.toLowerCase()) && !p.id.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  // Admin filters
  const filteredAdmins = adminsList.filter((a) => {
    if (statusFilter !== 'all' && a.status !== statusFilter) return false;
    if (searchQuery && !a.name.toLowerCase().includes(searchQuery.toLowerCase()) && !a.id.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  // Driver actions
  const approveDriver = (id: string) => {
    setDriversList((prev) => prev.map((d) => d.id === id ? { ...d, status: 'Active' as const, pendingReview: false, rating: 5.0 } : d));
    showToast('Driver approved successfully');
  };
  const rejectDriver = (id: string) => {
    setDriversList((prev) => prev.filter((d) => d.id !== id));
    showToast('Driver application rejected');
  };
  const deactivateDriver = (id: string) => {
    setDriversList((prev) => prev.map((d) => d.id === id ? { ...d, status: 'Inactive' as const } : d));
    showToast('Driver deactivated');
  };
  const activateDriver = (id: string) => {
    setDriversList((prev) => prev.map((d) => d.id === id ? { ...d, status: 'Active' as const } : d));
    showToast('Driver activated');
  };
  const deleteDriver = (id: string) => {
    setDriversList((prev) => prev.filter((d) => d.id !== id));
    showToast('Driver deleted');
  };

  // Passenger actions
  const suspendPassenger = (id: string) => {
    setPassengersList((prev) => prev.map((p) => p.id === id ? { ...p, status: 'Suspended' as const } : p));
    showToast('Passenger suspended');
  };
  const activatePassenger = (id: string) => {
    setPassengersList((prev) => prev.map((p) => p.id === id ? { ...p, status: 'Active' as const } : p));
    showToast('Passenger activated');
  };
  const deletePassenger = (id: string) => {
    setPassengersList((prev) => prev.filter((p) => p.id !== id));
    showToast('Passenger deleted');
  };

  // Admin actions
  const deactivateAdmin = (id: string) => {
    setAdminsList((prev) => prev.map((a) => a.id === id ? { ...a, status: 'Inactive' as const } : a));
    showToast('Admin deactivated');
  };
  const activateAdmin = (id: string) => {
    setAdminsList((prev) => prev.map((a) => a.id === id ? { ...a, status: 'Active' as const } : a));
    showToast('Admin activated');
  };
  const deleteAdmin = (id: string) => {
    setAdminsList((prev) => prev.filter((a) => a.id !== id));
    showToast('Admin removed');
  };

  const getAddLabel = () => {
    if (activeTab === 'passengers') return 'Add Passenger';
    if (activeTab === 'admins') return 'Add Admin';
    return 'Add Driver';
  };

  const getStatusOptions = () => {
    if (activeTab === 'passengers') return ['Active', 'Suspended', 'Inactive'];
    if (activeTab === 'admins') return ['Active', 'Inactive'];
    return ['Active', 'Inactive', 'Pending'];
  };

  const getTotalLabel = () => {
    if (activeTab === 'passengers') return `${filteredPassengers.length} of ${passengersList.length} passengers`;
    if (activeTab === 'admins') return `${filteredAdmins.length} of ${adminsList.length} admins`;
    return `${filteredDrivers.length} of ${driversList.length} drivers`;
  };

  return (
    <div className="users-page">
      {/* Toast */}
      {toast && (
        <div className="users-toast">
          <Check size={16} />
          <span>{toast}</span>
          <button onClick={() => setToast(null)}><X size={14} /></button>
        </div>
      )}

      <div className="users-header">
        <h1>User Management</h1>
        <div className="users-header-actions">
          <button className="users-btn primary">
            <Plus size={16} /> {getAddLabel()}
          </button>
          <button className="users-btn outline">
            <Download size={16} /> Export
          </button>
        </div>
      </div>

      <div className="users-tabs">
        <button
          className={`users-tab ${activeTab === 'passengers' ? 'active' : ''}`}
          onClick={() => { setActiveTab('passengers'); setSearchQuery(''); setStatusFilter('all'); }}
        >
          <Users size={16} /> Passengers
          <span className="tab-count">{passengersList.length}</span>
        </button>
        <button
          className={`users-tab ${activeTab === 'drivers' ? 'active' : ''}`}
          onClick={() => { setActiveTab('drivers'); setSearchQuery(''); setStatusFilter('all'); }}
        >
          <UserPlus size={16} /> Drivers
          {pendingCount > 0 && <span className="tab-badge">{pendingCount}</span>}
        </button>
        <button
          className={`users-tab ${activeTab === 'admins' ? 'active' : ''}`}
          onClick={() => { setActiveTab('admins'); setSearchQuery(''); setStatusFilter('all'); }}
        >
          <Shield size={16} /> Admins
          <span className="tab-count">{adminsList.length}</span>
        </button>
      </div>

      <div className="users-filters">
        <div className="users-search-wrap">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            placeholder={`Search ${activeTab} by name or ID...`}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="users-search"
          />
        </div>
        <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="users-filter">
          <option value="all">Status: All</option>
          {getStatusOptions().map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
        {activeTab === 'drivers' && (
          <>
            <select value={routeFilter} onChange={(e) => setRouteFilter(e.target.value)} className="users-filter">
              <option value="all">Route</option>
              <option value="138">Route 138</option>
              <option value="220">Route 220</option>
            </select>
            <select value={sortBy} onChange={(e) => setSortBy(e.target.value)} className="users-filter">
              <option value="name">Sort: Name</option>
              <option value="id">Sort: ID</option>
              <option value="rating">Sort: Rating</option>
            </select>
          </>
        )}
        <span className="users-showing">Showing {getTotalLabel()}</span>
      </div>

      {/* ===== DRIVERS TABLE ===== */}
      {activeTab === 'drivers' && (
        <div className="users-table-wrap">
          <table className="users-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>NAME</th>
                <th>EMAIL</th>
                <th>PHONE</th>
                <th>ROUTE</th>
                <th>STATUS</th>
                <th>ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {filteredDrivers.map((driver) => (
                <tr key={driver.id}>
                  <td className="driver-id">{driver.id}</td>
                  <td>
                    <div className="driver-name-cell">
                      <span className="driver-name">{driver.name}</span>
                      {driver.pendingReview ? (
                        <span className="driver-pending-label">Pending Review</span>
                      ) : (
                        <span className="driver-rating">Rating: {driver.rating}</span>
                      )}
                    </div>
                  </td>
                  <td className="driver-email">{driver.email}</td>
                  <td>{driver.phone}</td>
                  <td>
                    {driver.route ? (
                      <span className="route-num">{driver.route}</span>
                    ) : (
                      <span className="unassigned">Unassigned</span>
                    )}
                  </td>
                  <td>
                    <span className={`user-status-badge ${driver.status.toLowerCase()}`}>
                      <span className="status-dot-sm"></span>
                      {driver.status}
                    </span>
                  </td>
                  <td>
                    <div className="user-action-btns">
                      {driver.status === 'Pending' ? (
                        <>
                          <button className="user-action-btn green" onClick={() => approveDriver(driver.id)}>
                            <Check size={14} /> Approve
                          </button>
                          <button className="user-action-btn red-outline" onClick={() => rejectDriver(driver.id)}>
                            <X size={14} /> Reject
                          </button>
                        </>
                      ) : (
                        <>
                          <button className="user-action-btn blue">
                            <Pencil size={14} /> Edit
                          </button>
                          {driver.status === 'Active' ? (
                            <button className="user-action-btn gray" onClick={() => deactivateDriver(driver.id)}>
                              <Power size={14} /> Deactivate
                            </button>
                          ) : (
                            <button className="user-action-btn green" onClick={() => activateDriver(driver.id)}>
                              <Check size={14} /> Activate
                            </button>
                          )}
                          <button className="user-action-btn red" onClick={() => deleteDriver(driver.id)}>
                            <Trash2 size={14} /> Delete
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {filteredDrivers.length === 0 && (
                <tr><td colSpan={7} className="empty-row">No drivers found</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* ===== PASSENGERS TABLE ===== */}
      {activeTab === 'passengers' && (
        <div className="users-table-wrap">
          <table className="users-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>NAME</th>
                <th>EMAIL</th>
                <th>PHONE</th>
                <th>NIC</th>
                <th>TRIPS</th>
                <th>STATUS</th>
                <th>ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {filteredPassengers.map((psg) => (
                <tr key={psg.id}>
                  <td className="driver-id">{psg.id}</td>
                  <td>
                    <div className="driver-name-cell">
                      <span className="driver-name">{psg.name}</span>
                      <span className="driver-rating">Since {psg.registeredDate}</span>
                    </div>
                  </td>
                  <td className="driver-email">{psg.email}</td>
                  <td>{psg.phone}</td>
                  <td><span className="nic-badge">{psg.nic}</span></td>
                  <td>
                    <div className="trips-cell">
                      <span className="trips-today">{psg.tripsToday} today</span>
                      <span className="trips-total">{psg.totalTrips} total</span>
                    </div>
                  </td>
                  <td>
                    <span className={`user-status-badge ${psg.status.toLowerCase()}`}>
                      <span className="status-dot-sm"></span>
                      {psg.status}
                    </span>
                  </td>
                  <td>
                    <div className="user-action-btns">
                      <button className="user-action-btn blue">
                        <Pencil size={14} /> Edit
                      </button>
                      {psg.status === 'Active' ? (
                        <button className="user-action-btn gray" onClick={() => suspendPassenger(psg.id)}>
                          <Power size={14} /> Suspend
                        </button>
                      ) : psg.status === 'Suspended' ? (
                        <button className="user-action-btn green" onClick={() => activatePassenger(psg.id)}>
                          <Check size={14} /> Activate
                        </button>
                      ) : (
                        <button className="user-action-btn green" onClick={() => activatePassenger(psg.id)}>
                          <Check size={14} /> Activate
                        </button>
                      )}
                      <button className="user-action-btn red" onClick={() => deletePassenger(psg.id)}>
                        <Trash2 size={14} /> Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {filteredPassengers.length === 0 && (
                <tr><td colSpan={8} className="empty-row">No passengers found</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      {/* ===== ADMINS TABLE ===== */}
      {activeTab === 'admins' && (
        <div className="users-table-wrap">
          <table className="users-table">
            <thead>
              <tr>
                <th>ID</th>
                <th>NAME</th>
                <th>EMAIL</th>
                <th>PHONE</th>
                <th>ROLE</th>
                <th>LAST LOGIN</th>
                <th>STATUS</th>
                <th>ACTIONS</th>
              </tr>
            </thead>
            <tbody>
              {filteredAdmins.map((admin) => (
                <tr key={admin.id}>
                  <td className="driver-id">{admin.id}</td>
                  <td><span className="driver-name">{admin.name}</span></td>
                  <td className="driver-email">{admin.email}</td>
                  <td>{admin.phone}</td>
                  <td>
                    <span className={`role-badge role-${admin.role.toLowerCase().replace(' ', '-')}`}>
                      {admin.role}
                    </span>
                  </td>
                  <td className="last-login">{admin.lastLogin}</td>
                  <td>
                    <span className={`user-status-badge ${admin.status.toLowerCase()}`}>
                      <span className="status-dot-sm"></span>
                      {admin.status}
                    </span>
                  </td>
                  <td>
                    <div className="user-action-btns">
                      <button className="user-action-btn blue">
                        <Pencil size={14} /> Edit
                      </button>
                      {admin.status === 'Active' ? (
                        <button className="user-action-btn gray" onClick={() => deactivateAdmin(admin.id)}>
                          <Power size={14} /> Deactivate
                        </button>
                      ) : (
                        <button className="user-action-btn green" onClick={() => activateAdmin(admin.id)}>
                          <Check size={14} /> Activate
                        </button>
                      )}
                      {admin.role !== 'Super Admin' && (
                        <button className="user-action-btn red" onClick={() => deleteAdmin(admin.id)}>
                          <Trash2 size={14} /> Delete
                        </button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {filteredAdmins.length === 0 && (
                <tr><td colSpan={8} className="empty-row">No admins found</td></tr>
              )}
            </tbody>
          </table>
        </div>
      )}

      <div className="users-pagination">
        <span className="pagination-info">Showing {getTotalLabel()}</span>
        <div className="pagination-controls">
          <button className="page-btn" disabled={currentPage === 1} onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}>&larr;</button>
          {[1, 2, 3].map((p) => (
            <button
              key={p}
              className={`page-btn ${p === currentPage ? 'active' : ''}`}
              onClick={() => setCurrentPage(p)}
            >
              {p}
            </button>
          ))}
          <button className="page-btn" onClick={() => setCurrentPage((p) => p + 1)}>&rarr;</button>
        </div>
      </div>
    </div>
  );
}
