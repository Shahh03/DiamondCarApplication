import { CssBaseline } from '@mui/material';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import {
  createContext,
  useContext,
  useLayoutEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

export type PortalThemeMode = 'light' | 'dark';

interface PortalThemeContextValue {
  mode: PortalThemeMode;
  toggleMode: () => void;
}

const STORAGE_KEY = 'diamondcar-management-theme';

const PortalThemeContext = createContext<PortalThemeContextValue | null>(null);

function initialMode(): PortalThemeMode {
  if (typeof window === 'undefined') return 'light';

  const saved = window.localStorage.getItem(STORAGE_KEY);
  if (saved === 'light' || saved === 'dark') return saved;

  return window.matchMedia('(prefers-color-scheme: dark)').matches
    ? 'dark'
    : 'light';
}

export default function PortalThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<PortalThemeMode>(initialMode);

  useLayoutEffect(() => {
    document.documentElement.dataset.theme = mode;
    document.documentElement.style.colorScheme = mode;
    window.localStorage.setItem(STORAGE_KEY, mode);
  }, [mode]);

  const theme = useMemo(
    () =>
      createTheme({
        palette: {
          mode,
          primary: { main: '#2563eb' },
          success: { main: '#059669' },
          warning: { main: '#ea580c' },
          error: { main: '#dc2626' },
          background:
            mode === 'dark'
              ? { default: '#08111f', paper: '#111c2e' }
              : { default: '#f5f7fb', paper: '#ffffff' },
          text:
            mode === 'dark'
              ? { primary: '#e8eef8', secondary: '#9aa9bd' }
              : { primary: '#0f172a', secondary: '#64748b' },
        },
        shape: { borderRadius: 10 },
        typography: {
          fontFamily:
            'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        },
      }),
    [mode],
  );

  const value = useMemo<PortalThemeContextValue>(
    () => ({
      mode,
      toggleMode: () => setMode((current) => (current === 'dark' ? 'light' : 'dark')),
    }),
    [mode],
  );

  return (
    <PortalThemeContext.Provider value={value}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        {children}
      </ThemeProvider>
    </PortalThemeContext.Provider>
  );
}

export function usePortalTheme(): PortalThemeContextValue {
  const context = useContext(PortalThemeContext);
  if (!context) {
    throw new Error('usePortalTheme must be used inside PortalThemeProvider');
  }
  return context;
}
