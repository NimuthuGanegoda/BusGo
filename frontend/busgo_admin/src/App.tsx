import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import FleetMap from './pages/FleetMap';
import Emergencies from './pages/Emergencies';
import FleetMgmt from './pages/FleetMgmt';
import UserManagement from './pages/UserManagement';
import AuditLogs from './pages/AuditLogs';
import AdminLayout from './layouts/AdminLayout';
import FirstLoginSetup from './components/FirstLoginSetup';
import RecoveryRequests from './pages/RecoveryRequests';

function AppRoutes() {
  const { user, isLoading, isFirstLogin, accessToken, completeSetup } = useAuth();

  if (isLoading) {
    return (
      <div style={{
        minHeight: '100vh', display: 'flex',
        alignItems: 'center', justifyContent: 'center',
        background: '#f8fafc', color: '#6b7280', fontSize: '14px',
      }}>
        Loading...
      </div>
    );
  }

  // Force first-login setup — skip for developer role
  if (user && isFirstLogin && accessToken && user.role !== 'developer') {
    return (
      <FirstLoginSetup
        email={user.email}
        accessToken={accessToken}
        onComplete={completeSetup}
      />
    );
  }

  return (
    <Routes>
      <Route path="/admin/login" element={<Login />} />
      <Route path="/admin" element={<AdminLayout />}>
        <Route path="dashboard"          element={<Dashboard />} />
        <Route path="fleet-map"          element={<FleetMap />} />
        <Route path="emergencies"        element={<Emergencies />} />
        <Route path="fleet"              element={<FleetMgmt />} />
        <Route path="users"              element={<UserManagement />} />
        <Route path="audit-logs"         element={<AuditLogs />} />
        {/* Developer only */}
        <Route path="recovery-requests"  element={<RecoveryRequests />} />
        <Route index element={<Navigate to="dashboard" replace />} />
      </Route>
      <Route path="*" element={<Navigate to="/admin/login" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  );
}
