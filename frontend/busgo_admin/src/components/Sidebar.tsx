import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Map, Bus, AlertTriangle,
  Users, Shield, LogOut, X,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const NAV = [
  { to: '/admin/dashboard',        icon: LayoutDashboard, label: 'Dashboard'        },
  { to: '/admin/fleet-map',        icon: Map,             label: 'Fleet Map'        },
  { to: '/admin/fleet',           icon: Bus,             label: 'Fleet Management' },
  { to: '/admin/emergencies',      icon: AlertTriangle,   label: 'Emergencies'      },
  { to: '/admin/users',            icon: Users,           label: 'User Management'  },
  { to: '/admin/audit-logs',       icon: Shield,          label: 'Audit Logs'       },
];

type Props = {
  open: boolean;
  onClose: () => void;
};

export default function Sidebar({ open, onClose }: Props) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/admin/login');
  };

  return (
    <aside style={{
      width: 'var(--sidebar-width)',
      background: 'var(--surface)',
      height: '100vh',
      position: 'fixed',
      top: 0, left: 0,
      display: 'flex',
      flexDirection: 'column',
      padding: '1.5rem 1rem',
      borderRight: '1px solid var(--border)',
      zIndex: 100,
      transition: 'transform 0.3s ease',
      transform: open ? 'translateX(0)' : undefined,
      overflowY: 'auto',
    }}
      className="busgo-sidebar"
    >
      {/* ── Header ── */}
      <div style={{
        display: 'flex', alignItems: 'center',
        justifyContent: 'space-between',
        marginBottom: '2rem', padding: '0 0.5rem',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          {/* BUSGO logo mark */}
          <img
            src="/src/assets/busgo-axis-logo.jpeg"
            alt="BUSGO"
            style={{
              width: 40, height: 40,
              borderRadius: '10px',
              objectFit: 'cover',
              boxShadow: '0 4px 12px var(--primary-glow)',
            }}
          />
          <div>
            <div style={{ fontSize: '1.2rem', fontWeight: 700, color: 'var(--text)', lineHeight: 1 }}>
              BUSGO
            </div>
            <div style={{ fontSize: '0.65rem', color: 'var(--text-muted)', letterSpacing: '0.1em', textTransform: 'uppercase' }}>
              Admin Panel
            </div>
          </div>
        </div>

        {/* Mobile close button */}
        <button
          onClick={onClose}
          className="sidebar-close-btn"
          style={{
            display: 'none', background: 'none', border: 'none',
            color: 'var(--text-muted)', cursor: 'pointer', padding: '4px',
          }}
        >
          <X size={18} />
        </button>
      </div>

      {/* ── Nav label ── */}
      <div style={{
        fontSize: '0.65rem', fontWeight: 700,
        color: 'var(--text-muted)', letterSpacing: '0.12em',
        textTransform: 'uppercase', padding: '0 0.5rem',
        marginBottom: '0.5rem',
      }}>
        Main Menu
      </div>

      {/* ── Nav links ── */}
      <nav style={{ flex: 1 }}>
        <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          {NAV.map(({ to, icon: Icon, label }) => (
            <li key={to}>
              <NavLink
                to={to}
                onClick={onClose}
                style={({ isActive }) => ({
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.85rem',
                  padding: '0.8rem 1rem',
                  borderRadius: 'var(--radius-sm)',
                  textDecoration: 'none',
                  fontWeight: 500,
                  fontSize: '0.9rem',
                  transition: 'all 0.2s',
                  background: isActive ? 'var(--primary)' : 'transparent',
                  color:      isActive ? '#fff' : 'var(--text-muted)',
                  boxShadow:  isActive ? '0 4px 12px var(--primary-glow)' : 'none',
                })}
              >
                {({ isActive }) => (
                  <>
                    <Icon size={18} strokeWidth={isActive ? 2.5 : 1.8} />
                    <span>{label}</span>
                  </>
                )}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* ── Footer ── */}
      <div style={{ borderTop: '1px solid var(--border)', paddingTop: '1rem' }}>
        {/* User profile */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: '0.75rem',
          background: 'var(--surface-raised)',
          padding: '0.75rem',
          borderRadius: 'var(--radius-sm)',
          marginBottom: '0.75rem',
        }}>
          <div style={{
            width: 36, height: 36, borderRadius: '50%',
            background: 'var(--primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: '0.85rem', fontWeight: 700, color: '#fff',
            flexShrink: 0,
          }}>
            {user?.full_name?.charAt(0)?.toUpperCase() ?? 'A'}
          </div>
          <div style={{ overflow: 'hidden' }}>
            <div style={{
              fontSize: '0.85rem', fontWeight: 600,
              color: 'var(--text)', whiteSpace: 'nowrap',
              overflow: 'hidden', textOverflow: 'ellipsis',
            }}>
              {user?.full_name ?? 'Admin'}
            </div>
            <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
              Administrator
            </div>
          </div>
        </div>

        {/* Logout button */}
        <button
          onClick={handleLogout}
          style={{
            display: 'flex', alignItems: 'center', gap: '0.85rem',
            width: '100%', padding: '0.75rem 1rem',
            background: 'none', border: 'none',
            borderRadius: 'var(--radius-sm)',
            color: 'var(--text-muted)',
            fontFamily: 'var(--font)',
            fontSize: '0.9rem', fontWeight: 500,
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
          onMouseEnter={e => {
            e.currentTarget.style.background = 'rgba(220,53,69,0.12)';
            e.currentTarget.style.color = 'var(--danger)';
          }}
          onMouseLeave={e => {
            e.currentTarget.style.background = 'none';
            e.currentTarget.style.color = 'var(--text-muted)';
          }}
        >
          <LogOut size={18} />
          <span>Logout</span>
        </button>
      </div>

      {/* ── Responsive styles ── */}
      <style>{`
        @media (max-width: 992px) {
          .busgo-sidebar {
            transform: ${open ? 'translateX(0)' : 'translateX(-100%)'} !important;
          }
          .sidebar-close-btn {
            display: flex !important;
          }
        }
      `}</style>
    </aside>
  );
}




