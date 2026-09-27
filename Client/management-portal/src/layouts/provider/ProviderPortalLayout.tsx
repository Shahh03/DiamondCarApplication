import {
  AccountBalanceWalletOutlined,
  ApartmentOutlined,
  CalendarMonthOutlined,
  DashboardOutlined,
  DirectionsCarOutlined,
  HelpOutlineRounded,
  LogoutRounded,
  MenuRounded,
} from '@mui/icons-material';
import { useEffect, useState } from 'react';
import {
  NavLink,
  Outlet,
  useLocation,
  useNavigate,
} from 'react-router-dom';

import { logoutManagementUser } from '../../api/authentication/authApi';
import diamondCarLogo from '../../assets/diamondcar-logo.svg';
import { readSession } from '../../core/session';
import ProviderNotificationBell from '../../components/notifications/ProviderNotificationBell';
import ThemeToggle from '../../components/theme/ThemeToggle';

import './ProviderPortalLayout.css';

const navigation = [
  {
    to: '/provider/dashboard',
    label: 'Dashboard',
    icon: DashboardOutlined,
  },
  {
    to: '/provider/fleet',
    label: 'Fleet',
    icon: DirectionsCarOutlined,
  },
  {
    to: '/provider/bookings',
    label: 'Bookings',
    icon: CalendarMonthOutlined,
  },
  {
    to: '/provider/earnings',
    label: 'Earnings',
    icon: AccountBalanceWalletOutlined,
  },
  {
    to: '/provider/company',
    label: 'Company',
    icon: ApartmentOutlined,
  },
];

export default function ProviderPortalLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const [session, setSession] = useState(readSession);

  useEffect(() => {
    const syncSession = () => setSession(readSession());
    window.addEventListener('diamondcar-session-changed', syncSession);
    return () => window.removeEventListener('diamondcar-session-changed', syncSession);
  }, []);

  const [menuOpen, setMenuOpen] = useState(false);

  const displayName =
    session?.user.companyName?.trim() ||
    session?.user.username?.trim() ||
    'Provider';

  const profilePicture = session?.user.profilePicture?.trim();
  const avatarLetter = displayName.charAt(0).toUpperCase();

  useEffect(() => {
    setMenuOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (!menuOpen) return undefined;

    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setMenuOpen(false);
      }
    }

    document.addEventListener('keydown', closeOnEscape);

    return () => {
      document.removeEventListener('keydown', closeOnEscape);
    };
  }, [menuOpen]);

  async function handleLogout() {
    await logoutManagementUser();
    navigate('/login', { replace: true });
  }

  return (
    <div className="provider-layout">
      {menuOpen && (
        <button
          className="provider-layout__scrim"
          type="button"
          aria-label="Close navigation"
          onClick={() => setMenuOpen(false)}
        />
      )}

      <aside
        className={[
          'provider-layout__sidebar',
          menuOpen ? 'provider-layout__sidebar--open' : '',
        ]
          .filter(Boolean)
          .join(' ')}
      >
        <NavLink
          className="provider-layout__brand"
          to="/provider/dashboard"
          aria-label="DiamondCar provider dashboard"
          onClick={() => setMenuOpen(false)}
        >
          <img
            className="provider-layout__logo"
            src={diamondCarLogo}
            alt="DiamondCar"
          />
        </NavLink>

        <nav
          className="provider-layout__navigation"
          aria-label="Provider navigation"
        >
          {navigation.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) =>
                [
                  'provider-layout__nav-link',
                  isActive ? 'provider-layout__nav-link--active' : '',
                ]
                  .filter(Boolean)
                  .join(' ')
              }
            >
              <Icon />
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="provider-layout__sidebar-footer">
          <button
            className="provider-layout__footer-action"
            type="button"
          >
            <HelpOutlineRounded />
            <span>Help &amp; Support</span>
          </button>

          <button
            className="provider-layout__footer-action"
            type="button"
            onClick={() => void handleLogout()}
          >
            <LogoutRounded />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      <section className="provider-layout__workspace">
        <header className="provider-layout__topbar">
          <button
            className="provider-layout__menu-button"
            type="button"
            aria-label="Open navigation"
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(true)}
          >
            <MenuRounded />
          </button>

          <div className="provider-layout__user-actions">
            <ThemeToggle />
            <ProviderNotificationBell />

            <div className="provider-layout__user">
              {profilePicture ? (
                <img
                  className="provider-layout__avatar"
                  src={profilePicture}
                  alt={`${displayName} profile`}
                />
              ) : (
                <span className="provider-layout__avatar provider-layout__avatar--fallback">
                  {avatarLetter}
                </span>
              )}

              <span className="provider-layout__user-copy">
                <strong>{displayName}</strong>
                <small>Provider</small>
              </span>
            </div>
          </div>
        </header>

        <div className="provider-layout__content">
          <Outlet />
        </div>
      </section>
    </div>
  );
}
