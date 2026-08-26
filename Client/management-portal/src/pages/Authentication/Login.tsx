import {
  ArrowForwardRounded,
  DirectionsCarRounded,
  LockOutlined,
  MailOutlineRounded,
  VisibilityOffOutlined,
  VisibilityOutlined,
} from '@mui/icons-material';
import { type FormEvent, useState } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';

import {
  loginManagementUser,
  logoutManagementUser,
} from '../../api/authentication/authApi';
import {
  isManagementRole,
  managementHome,
  readSession,
} from '../../core/session';

export default function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const existingSession = readSession();
  const existingUser = existingSession?.user;

  if (
    existingUser &&
    isManagementRole(existingUser.type) &&
    (existingUser.type === 'Admin' || existingUser.status === 'Accepted')
  ) {
    return <Navigate to={managementHome(existingUser)} replace />;
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!identifier.trim() || !password) {
      setError('Enter your email or username and password.');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      const session = await loginManagementUser(identifier, password);

      if (
        session.user.type === 'Provider' &&
        session.user.status !== 'Accepted'
      ) {
        const status = session.user.status;
        await logoutManagementUser();

        throw new Error(
          status === 'Rejected'
            ? 'Your provider application was rejected. Contact DiamondCar support for help.'
            : 'Your provider application is still awaiting administrator approval.',
        );
      }

      const requestedDestination = (
        location.state as { from?: string } | null
      )?.from;

      let destination = managementHome(session.user);

      if (
        requestedDestination &&
        ((session.user.type === 'Admin' &&
          requestedDestination.startsWith('/admin/')) ||
          (session.user.type === 'Provider' &&
            requestedDestination.startsWith('/provider/')))
      ) {
        destination = requestedDestination;
      }

      navigate(destination, { replace: true });
    } catch (loginError) {
      setError(
        loginError instanceof Error
          ? loginError.message
          : 'Could not sign in.',
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-brand-panel">
        <div className="login-brand-lockup">
          <span className="brand-mark large">
            <DirectionsCarRounded />
          </span>
          <span>DiamondCar</span>
        </div>

        <div className="login-brand-copy">
          <span className="eyebrow light">MANAGEMENT PORTAL</span>
          <h1>Operate DiamondCar with clarity.</h1>
          <p>
            A secure workspace for providers managing their businesses and
            administrators overseeing the DiamondCar platform.
          </p>
        </div>

        <div className="login-security-note">
          <LockOutlined />
          <span>Private access for approved management accounts</span>
        </div>
      </section>

      <section className="login-form-panel">
        <form className="login-card" onSubmit={handleSubmit} noValidate>
          <div>
            <span className="eyebrow">WELCOME BACK</span>
            <h2>Sign in to your portal</h2>
            <p>Use your approved administrator or provider credentials.</p>
          </div>

          {error && <div className="form-alert">{error}</div>}

          <label className="field-label" htmlFor="identifier">
            Email or username
          </label>
          <div className="input-shell">
            <MailOutlineRounded />
            <input
              id="identifier"
              autoComplete="username"
              value={identifier}
              onChange={(event) => setIdentifier(event.target.value)}
              placeholder="management@diamondcar.com"
              disabled={submitting}
            />
          </div>

          <label className="field-label" htmlFor="password">
            Password
          </label>
          <div className="input-shell">
            <LockOutlined />
            <input
              id="password"
              type={showPassword ? 'text' : 'password'}
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Enter your password"
              disabled={submitting}
            />
            <button
              type="button"
              className="input-action"
              onClick={() => setShowPassword((visible) => !visible)}
              aria-label={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? (
                <VisibilityOffOutlined />
              ) : (
                <VisibilityOutlined />
              )}
            </button>
          </div>

          <button
            type="submit"
            className="primary-button login-submit"
            disabled={submitting}
          >
            <span>{submitting ? 'Signing in…' : 'Sign in'}</span>
            {!submitting && <ArrowForwardRounded />}
          </button>

          <div className="auth-switch">
            <span>Want to list vehicles with DiamondCar?</span>
            <button type="button" onClick={() => navigate('/signup')}>
              Apply as a provider
            </button>
          </div>
        </form>
      </section>
    </main>
  );
}
