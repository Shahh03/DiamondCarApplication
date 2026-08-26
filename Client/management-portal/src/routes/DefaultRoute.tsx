import { Navigate } from 'react-router-dom';

import {
  isManagementRole,
  managementHome,
  readSession,
} from '../core/session';

export default function DefaultRoute() {
  const session = readSession();

  const canEnter =
    session &&
    isManagementRole(session.user.type) &&
    (
      session.user.type === 'Admin' ||
      session.user.status === 'Accepted'
    );

  if (canEnter) {
    return <Navigate to={managementHome(session.user)} replace />;
  }

  return <Navigate to="/login" replace />;
}