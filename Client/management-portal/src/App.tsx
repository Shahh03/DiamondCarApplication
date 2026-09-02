import { Route, Routes } from 'react-router-dom';

import ProviderPortalLayout from './layouts/provider/ProviderPortalLayout';
import LoginPage from './pages/Authentication/Login';
import SignUpPage from './pages/Authentication/SignUp';
import AdminVehicleReviewsPage from './pages/admin/vehicles/AdminVehicleReviewsPage';
import ProviderDashboardPage from './pages/provider/dashboard/ProviderDashboardPage';
import ProviderBookingsPage from './pages/provider/bookings/ProviderBookingsPage';
import ProviderFleetPage from './pages/provider/fleet/ProviderFleetPage';
import ProviderFleetAddPage from './pages/provider/fleet/add/ProviderFleetAddPage';
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
            path="/provider/fleet/add"
            element={<ProviderFleetAddPage />}
          />
          <Route
            path="/provider/bookings"
            element={<ProviderBookingsPage />}
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
          element={<AdminVehicleReviewsPage />}
        />
        <Route
          path="/admin/vehicles"
          element={<AdminVehicleReviewsPage />}
        />
      </Route>

      <Route path="*" element={<DefaultRoute />} />
    </Routes>
  );
}
