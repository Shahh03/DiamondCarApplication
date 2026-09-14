import { Sentry } from './core/monitoring';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import App from './App';
import './index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Sentry.ErrorBoundary fallback={
      <main role="alert" style={{ maxWidth: 480, margin: '15vh auto', padding: 28, textAlign: 'center', fontFamily: 'sans-serif' }}>
        <h1>Something went wrong</h1>
        <p>Please reload the page and try again.</p>
        <button type="button" onClick={() => window.location.reload()}>Reload page</button>
      </main>
    }>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
    </Sentry.ErrorBoundary>
  </StrictMode>,
);
