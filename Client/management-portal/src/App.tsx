import { Route, Routes, useLocation } from 'react-router-dom';

import ThemeToggle from './components/theme/ThemeToggle';
import ProviderPortalLayout from './layouts/provider/ProviderPortalLayout';
import LoginPage from './pages/Authentication/Login';
import SignUpPage from './pages/Authentication/SignUp';
import AdminVehicleReviewsPage from './pages/admin/vehicles/AdminVehicleReviewsPage';
import ProviderBookingsPage from './pages/provider/bookings/ProviderBookingsPage';
import ProviderDashboardPage from './pages/provider/dashboard/ProviderDashboardPage';
import ProviderEarningsPage from './pages/provider/earnings/ProviderEarningsPage';
import ProviderFleetPage from './pages/provider/fleet/ProviderFleetPage';
import ProviderFleetAddPage from './pages/provider/fleet/add/ProviderFleetAddPage';
import ProviderFleetEditPage from './pages/provider/fleet/edit/ProviderFleetEditPage';
import ProviderCompanyPage from './pages/provider/company/ProviderCompanyPage';
import ProviderNotificationsPage from './pages/provider/notifications/ProviderNotificationsPage';
import DefaultRoute from './routes/DefaultRoute';
import RoleGuard from './routes/RoleGuard';

import './App.css';

export default function App() {
  const location = useLocation();
  const providerLayoutOwnsToggle = location.pathname.startsWith('/provider/');

  return (
    <>
      {!providerLayoutOwnsToggle && <ThemeToggle floating />}
      <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/signup" element={<SignUpPage />} />

      <Route element={<RoleGuard role="Provider" />}>
        <Route element={<ProviderPortalLayout />}>
          <Route path="/provider/dashboard" element={<ProviderDashboardPage />} />
          <Route path="/provider/fleet" element={<ProviderFleetPage />} />
          <Route path="/provider/fleet/:vehicleId/edit" element={<ProviderFleetEditPage />} />
          <Route path="/provider/fleet/add" element={<ProviderFleetAddPage />} />
          <Route path="/provider/bookings" element={<ProviderBookingsPage />} />
          <Route path="/provider/earnings" element={<ProviderEarningsPage />} />
          <Route path="/provider/company" element={<ProviderCompanyPage />} />
          <Route path="/provider/notifications" element={<ProviderNotificationsPage />} />
        </Route>
      </Route>

      <Route element={<RoleGuard role="Admin" />}>
        <Route path="/admin/dashboard" element={<AdminVehicleReviewsPage />} />
        <Route path="/admin/vehicles" element={<AdminVehicleReviewsPage />} />
      </Route>

      <Route path="*" element={<DefaultRoute />} />
      </Routes>
    </>
  );
}
