import { Route, Routes } from 'react-router-dom';

import ProviderPortalLayout from './layouts/provider/ProviderPortalLayout';
import LoginPage from './pages/Authentication/Login';
import SignUpPage from './pages/Authentication/SignUp';
import ProviderDashboardPage from './pages/provider/dashboard/ProviderDashboardPage';
import ProviderFleetPage from './pages/provider/fleet/ProviderFleetPage';
import ProviderFleetEditPage from './pages/provider/fleet/edit/ProviderFleetEditPage';
import ProviderPlaceholderPage from './pages/provider/ProviderPlaceholderPage';
import DefaultRoute from './routes/DefaultRoute';
import RoleGuard from './routes/RoleGuard';

import './App.css';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/signup" element={<SignUpPage />} />

      <Route element={<RoleGuard role="Provider" />}>
        <Route element={<ProviderPortalLayout />}>
          <Route
            path="/provider/dashboard"
            element={<ProviderDashboardPage />}
          />
          <Route
            path="/provider/fleet"
            element={<ProviderFleetPage />}
          />
          <Route
            path="/provider/fleet/:vehicleId/edit"
            element={<ProviderFleetEditPage />}
          />
          <Route
            path="/provider/bookings"
            element={<ProviderPlaceholderPage />}
          />
          <Route
            path="/provider/earnings"
            element={<ProviderPlaceholderPage />}
          />
          <Route
            path="/provider/company"
            element={<ProviderPlaceholderPage />}
          />
        </Route>
      </Route>

      <Route element={<RoleGuard role="Admin" />}>
        <Route
          path="/admin/dashboard"
          element={
            <main className="auth-placeholder">
              Admin dashboard comes next.
            </main>
          }
        />
      </Route>

      <Route path="*" element={<DefaultRoute />} />
    </Routes>
  );
}
