import { Navigate, Outlet, useLocation } from 'react-router-dom';

import {
  isManagementRole,
  managementHome,
  readSession,
  type ManagementRole,
} from '../core/session';

interface RoleGuardProps {
  role: ManagementRole;
}

export default function RoleGuard({ role }: RoleGuardProps) {
  const location = useLocation();
  const session = readSession();

  if (!session) {
    return (
      <Navigate
        to="/login"
        replace
        state={{ from: location.pathname }}
      />
    );
  }

  if (!isManagementRole(session.user.type)) {
    return <Navigate to="/login" replace />;
  }

  if (
    session.user.type === 'Provider' &&
    session.user.status !== 'Accepted'
  ) {
    return <Navigate to="/login" replace />;
  }

  if (session.user.type !== role) {
    return <Navigate to={managementHome(session.user)} replace />;
  }

  return <Outlet />;
}