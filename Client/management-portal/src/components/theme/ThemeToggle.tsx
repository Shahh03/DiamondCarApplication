import { DarkModeRounded, LightModeRounded } from '@mui/icons-material';

import { usePortalTheme } from '../../theme/PortalThemeProvider';

import './ThemeToggle.css';

export default function ThemeToggle({ floating = false }: { floating?: boolean }) {
  const { mode, toggleMode } = usePortalTheme();
  const dark = mode === 'dark';

  return (
    <button
      className={`portal-theme-toggle${floating ? ' portal-theme-toggle--floating' : ''}`}
      type="button"
      aria-label={dark ? 'Switch to light mode' : 'Switch to dark mode'}
      aria-pressed={dark}
      title={dark ? 'Light mode' : 'Dark mode'}
      onClick={toggleMode}
    >
      {dark ? <LightModeRounded /> : <DarkModeRounded />}
    </button>
  );
}
