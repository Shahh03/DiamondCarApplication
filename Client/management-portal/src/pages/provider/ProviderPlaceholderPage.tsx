import { useLocation } from 'react-router-dom';

export default function ProviderPlaceholderPage() {
  const section = useLocation().pathname.split('/').pop() || 'page';
  return (
    <main style={{ padding: 32 }}>
      <div style={{ padding: 32, border: '1px solid #e2e8f1', borderRadius: 14, background: '#fff' }}>
        <h1 style={{ marginTop: 0, textTransform: 'capitalize' }}>{section}</h1>
        <p style={{ color: '#6f7c91' }}>This dashboard section is ready to be implemented next.</p>
      </div>
    </main>
  );
}