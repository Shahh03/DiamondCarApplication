export type ManagementRole = 'Admin' | 'Provider';
export type ProviderStatus = 'Pending' | 'Rejected' | 'Accepted';

export interface PortalUser {
  _id: string;
  type: ManagementRole | 'Renter';
  username?: string;
  email?: string;
  companyName?: string;
  profilePicture?: string;
  currency?: string;
  status?: ProviderStatus;
}

export interface PortalSession {
  accessToken: string;
  refreshToken: string;
  user: PortalUser;
}

const SESSION_KEY = 'diamondcar_management_portal_session';

export function readSession(): PortalSession | null {
  try {
    const stored = window.sessionStorage.getItem(SESSION_KEY);
    if (!stored) return null;

    const parsed = JSON.parse(stored) as Partial<PortalSession>;
    if (
      !parsed.accessToken ||
      !parsed.refreshToken ||
      !parsed.user?._id ||
      !parsed.user.type
    ) {
      return null;
    }

    return parsed as PortalSession;
  } catch {
    return null;
  }
}

export function writeSession(session: PortalSession): void {
  window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  window.dispatchEvent(new Event('diamondcar-session-changed'));
}

export function clearSession(): void {
  window.sessionStorage.removeItem(SESSION_KEY);
  window.dispatchEvent(new Event('diamondcar-session-changed'));
}

export function isManagementRole(
  type: PortalUser['type'],
): type is ManagementRole {
  return type === 'Admin' || type === 'Provider';
}

export function managementHome(user: PortalUser): string {
  if (user.type === 'Admin') return '/admin/dashboard';
  if (user.type === 'Provider') return '/provider/dashboard';
  return '/login';
}
