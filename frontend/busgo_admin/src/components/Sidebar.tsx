import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  Map,
  AlertTriangle,
  Bus,
  Users,
  FileText,
} from 'lucide-react';
import './Sidebar.css';

const navItems = [
  { label: 'OVERVIEW', items: [
    { to: '/admin/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  ]},
  { label: 'OPERATIONS', items: [
    { to: '/admin/fleet-map', icon: Map, label: 'Fleet Map' },
    { to: '/admin/emergencies', icon: AlertTriangle, label: 'Emergencies', badge: 3 },
    { to: '/admin/fleet', icon: Bus, label: 'Fleet Mgmt' },
  ]},
  { label: 'ADMIN', items: [
    { to: '/admin/users', icon: Users, label: 'Users' },
    { to: '/admin/audit-logs', icon: FileText, label: 'Audit Logs' },
  ]},
];

export default function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-logo">
        <img src="/busgo-logo.jpeg" alt="BUSGO" className="sidebar-logo-img" />
        <div>
          <div className="sidebar-logo-title">BUSGO</div>
          <div className="sidebar-logo-subtitle">AXIS ADMIN</div>
        </div>
      </div>

      <nav className="sidebar-nav">
        {navItems.map((section) => (
          <div key={section.label} className="sidebar-section">
            <div className="sidebar-section-label">{section.label}</div>
            {section.items.map((item) => (
              <NavLink
                key={item.to}
                to={item.to}
                className={({ isActive }) =>
                  `sidebar-link ${isActive ? 'active' : ''}`
                }
              >
                <item.icon size={20} />
                <span>{item.label}</span>
                {item.badge && (
                  <span className="sidebar-badge">{item.badge}</span>
                )}
              </NavLink>
            ))}
          </div>
        ))}
      </nav>

      <div className="sidebar-user">
        <div className="sidebar-user-avatar">A</div>
        <div>
          <div className="sidebar-user-name">Admin</div>
          <div className="sidebar-user-status">
            <span className="status-dot online"></span> Online
          </div>
        </div>
      </div>
    </aside>
  );
}
