import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import FleetMap from './pages/FleetMap';
import Emergencies from './pages/Emergencies';
import FleetMgmt from './pages/FleetMgmt';
import UserManagement from './pages/UserManagement';
import AuditLogs from './pages/AuditLogs';
import AdminLayout from './layouts/AdminLayout';

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/admin/login" element={<Login />} />
          <Route path="/admin" element={<AdminLayout />}>
            <Route path="dashboard"   element={<Dashboard />} />
            <Route path="fleet-map"   element={<FleetMap />} />
            <Route path="emergencies" element={<Emergencies />} />
            <Route path="fleet"       element={<FleetMgmt />} />
            <Route path="users"       element={<UserManagement />} />
            <Route path="audit-logs"  element={<AuditLogs />} />
            <Route index element={<Navigate to="dashboard" replace />} />
          </Route>
          <Route path="*" element={<Navigate to="/admin/login" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}




