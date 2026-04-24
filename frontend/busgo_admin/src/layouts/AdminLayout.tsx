import { useState } from 'react';
import { Outlet } from 'react-router-dom';
import Sidebar from '../components/Sidebar';
import { Bell, Search, Menu } from 'lucide-react';

export default function AdminLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>

      {/* Sidebar */}
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Mobile overlay */}
      {sidebarOpen && (
        <div onClick={() => setSidebarOpen(false)} style={{
          position: 'fixed', inset: 0,
          background: 'rgba(0,0,0,0.5)',
          zIndex: 99,
        }} />
      )}

      {/* Main area — no background override, lets each page control its own */}
      <div style={{
        marginLeft: 'var(--sidebar-width)',
        width: 'calc(100% - var(--sidebar-width))',
        display: 'flex',
        flexDirection: 'column',
        minHeight: '100vh',
      }} className="main-area">

        {/* Top header */}
        <header style={{
          height: '64px',
          background: '#1a1f2e',
          borderBottom: '1px solid #2d3a4a',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 2rem',
          position: 'sticky',
          top: 0,
          zIndex: 50,
          boxShadow: '0 2px 12px rgba(0,0,0,0.15)',
        }}>
          {/* Left — hamburger + search */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <button
              onClick={() => setSidebarOpen(v => !v)}
              className="menu-toggle-btn"
              style={{
                display: 'none', background: 'none', border: 'none',
                color: '#e0e0e0', cursor: 'pointer', padding: '4px',
              }}
            >
              <Menu size={22} />
            </button>
            <div style={{ position: 'relative' }}>
              <Search size={14} style={{
                position: 'absolute', left: '12px',
                top: '50%', transform: 'translateY(-50%)',
                color: '#a0a0b0',
              }} />
              <input
                placeholder="Search..."
                style={{
                  background: '#2c2f3b',
                  border: '1px solid #3a3d52',
                  borderRadius: '20px',
                  padding: '7px 14px 7px 34px',
                  color: '#e0e0e0',
                  fontFamily: 'inherit',
                  fontSize: '13px',
                  width: '220px',
                  outline: 'none',
                }}
              />
            </div>
          </div>

          {/* Right — bell */}
          <button style={{
            background: 'none', border: 'none',
            color: '#a0a0b0', cursor: 'pointer',
            display: 'flex', padding: '6px', borderRadius: '8px',
          }}
            onMouseEnter={e => (e.currentTarget.style.color = '#7b68ee')}
            onMouseLeave={e => (e.currentTarget.style.color = '#a0a0b0')}
          >
            <Bell size={20} />
          </button>
        </header>

        {/* Page content */}
        <main style={{ flex: 1 }} className="page-enter">
          <Outlet />
        </main>
      </div>

      <style>{`
        @media (max-width: 992px) {
          .main-area { margin-left: 0 !important; width: 100% !important; }
          .menu-toggle-btn { display: flex !important; }
        }
      `}</style>
    </div>
  );
}
