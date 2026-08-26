import {
  AccountBalanceWalletOutlined,
  ArrowForwardRounded,
  BuildOutlined,
  CalendarMonthOutlined,
  DirectionsCarOutlined,
  InsertChartOutlined,
  TaskAltRounded,
} from '@mui/icons-material';
import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { Link } from 'react-router-dom';

import {
  getProviderDashboard,
  type BookingRecord,
  type ProviderDashboardData,
} from '../../../api/provider/providerDashboardApi';
import { readSession } from '../../../core/session';
import './ProviderDashboardPage.css';

function money(value: number, currency: string) {
  return new Intl.NumberFormat('en', {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

function dateLabel(value?: string) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric', year: 'numeric' }).format(date);
}

function bookingAmount(booking: BookingRecord) {
  return Number(booking.payment?.amount ?? booking.totalPrice ?? 0);
}

function isThisMonth(value?: string) {
  if (!value) return false;
  const date = new Date(value);
  const now = new Date();
  return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth();
}

export default function ProviderDashboardPage() {
  const providerId = readSession()?.user._id ?? '';
  const [data, setData] = useState<ProviderDashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!providerId) return;
    setLoading(true);
    setError(null);
    try {
      setData(await getProviderDashboard(providerId));
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Could not load dashboard.');
    } finally {
      setLoading(false);
    }
  }, [providerId]);

  useEffect(() => { void load(); }, [load]);

  const metrics = useMemo(() => {
    const fleet = data?.fleet ?? [];
    const bookings = data?.bookings ?? [];
    const now = new Date();
    const active = bookings.filter((booking) =>
      booking.status === 'Confirmed' && (!booking.endDate || new Date(booking.endDate) >= now),
    );
    const rentedIds = new Set(active.map((booking) => booking.carVariant?._id).filter(Boolean));
    const available = fleet.filter((vehicle) => vehicle.isAvailable && !rentedIds.has(vehicle._id)).length;
    const unavailable = Math.max(0, fleet.length - available - rentedIds.size);
    const monthlyCompleted = bookings.filter((booking) =>
      booking.payment?.paymentStatus === 'Completed' &&
      isThisMonth(booking.payment.paymentDate || booking.createdAt),
    );
    const revenue = monthlyCompleted.reduce((sum, booking) => sum + bookingAmount(booking), 0);
    const utilization = fleet.length ? Math.round((rentedIds.size / fleet.length) * 100) : 0;
    return { active, rented: rentedIds.size, available, unavailable, revenue, utilization };
  }, [data]);

  if (loading && !data) {
    return <main className="provider-dashboard-state"><span className="dashboard-spinner" />Loading your dashboard…</main>;
  }

  if (error && !data) {
    return <main className="provider-dashboard-state"><h1>Dashboard unavailable</h1><p>{error}</p><button onClick={() => void load()}>Try again</button></main>;
  }

  if (!data) return null;

  const providerName = data.provider.companyName || data.provider.username || 'Provider';
  const firstName = (data.provider.username || providerName).split(/\s+/)[0];
  const currency = (data.provider.currency || readSession()?.user.currency || 'AED').toUpperCase();
  const recentBookings = [...data.bookings]
    .sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime())
    .slice(0, 4);

  return (
    <main className="provider-dashboard">
      <section className="dashboard-hero">
        <div><p>Good morning, {firstName}</p><h1>{providerName}</h1><span>Manage your cars, bookings and earnings.</span></div>
        <div className="hero-skyline" aria-hidden="true">▥ ▥ ▥ ◇ ▥</div>
      </section>

      {error && <div className="dashboard-warning">Some information may be outdated. {error} <button onClick={() => void load()}>Refresh</button></div>}

      <section className="dashboard-kpis">
        <Kpi icon={<DirectionsCarOutlined />} label="Total vehicles" value={String(data.fleet.length)} link="/provider/fleet" linkLabel="View all fleet" />
        <Kpi teal icon={<TaskAltRounded />} label="Available" value={String(metrics.available)} link="/provider/fleet" linkLabel="View available" />
        <Kpi icon={<CalendarMonthOutlined />} label="Active bookings" value={String(metrics.active.length)} link="/provider/bookings" linkLabel="View bookings" />
        <Kpi teal icon={<AccountBalanceWalletOutlined />} label="Monthly earnings" value={money(metrics.revenue, currency)} link="/provider/earnings" linkLabel="View earnings" compact />
      </section>

      <section className="dashboard-analytics">
        <article className="dashboard-card revenue-card">
          <header><div><h2>Revenue overview</h2><strong>{money(metrics.revenue, currency)}</strong><small>This month</small></div><span className="period-pill">This Month</span></header>
          <RevenueChart bookings={data.bookings} />
        </article>

        <article className="dashboard-card utilization-card">
          <h2>Fleet utilization</h2>
          <div className="utilization-content">
            <div className="donut" style={{ '--utilization': `${metrics.utilization * 3.6}deg` } as CSSProperties}><span><strong>{metrics.utilization}%</strong><small>Utilized</small></span></div>
            <div className="utilization-legend">
              <Legend color="#1767e8" label="On rent" value={metrics.rented} />
              <Legend color="#1db6ad" label="Available" value={metrics.available} />
              <Legend color="#bec6d2" label="Unavailable" value={metrics.unavailable} />
              <div className="legend-total"><span>Total vehicles</span><strong>{data.fleet.length}</strong></div>
            </div>
          </div>
        </article>
      </section>

      <section className="dashboard-bottom-grid">
        <article className="dashboard-card recent-card">
          <header><h2>Recent bookings</h2><Link to="/provider/bookings">View all bookings <ArrowForwardRounded /></Link></header>
          {recentBookings.length ? <div className="booking-table-wrap"><table><thead><tr><th>Booking</th><th>Customer</th><th>Vehicle</th><th>Pickup</th><th>Return</th><th>Status</th><th>Amount</th></tr></thead><tbody>{recentBookings.map((booking) => <BookingRow key={booking._id} booking={booking} currency={currency} />)}</tbody></table></div> : <div className="dashboard-empty">No bookings yet.</div>}
        </article>

        <article className="dashboard-card quick-card">
          <h2>Quick actions</h2>
          <div className="quick-grid">
            <QuickAction to="/provider/fleet" icon={<DirectionsCarOutlined />} title="Add vehicle" subtitle="Manage your fleet" />
            <QuickAction to="/provider/bookings" icon={<CalendarMonthOutlined />} title="View bookings" subtitle="Review bookings" teal />
            <QuickAction to="/provider/fleet" icon={<BuildOutlined />} title="Maintenance" subtitle="Review vehicles" orange />
            <QuickAction to="/provider/earnings" icon={<InsertChartOutlined />} title="View reports" subtitle="Earnings & insights" purple />
          </div>
        </article>
      </section>
    </main>
  );
}

function Kpi({ icon, label, value, link, linkLabel, teal = false, compact = false }: { icon: ReactNode; label: string; value: string; link: string; linkLabel: string; teal?: boolean; compact?: boolean }) {
  return <article className="dashboard-card kpi-card"><div className={`kpi-icon ${teal ? 'teal' : ''}`}>{icon}</div><div className="kpi-copy"><span>{label}</span><strong className={compact ? 'compact' : ''}>{value}</strong></div><Link to={link}>{linkLabel}<ArrowForwardRounded /></Link></article>;
}

function Legend({ color, label, value }: { color: string; label: string; value: number }) {
  return <div className="legend-row"><i style={{ background: color }} /><span>{label}</span><strong>{value}</strong></div>;
}

function BookingRow({ booking, currency }: { booking: BookingRecord; currency: string }) {
  const car = booking.carVariant?.car;
  const customer = booking.renter?.name || booking.renter?.username || 'Renter';
  const status = booking.status || 'Confirmed';
  return <tr><td>#{booking._id.slice(-7).toUpperCase()}</td><td><div className="customer-cell"><span>{customer.charAt(0).toUpperCase()}</span>{customer}</div></td><td>{[car?.brand, car?.model].filter(Boolean).join(' ') || 'Vehicle'}</td><td>{dateLabel(booking.startDate)}</td><td>{dateLabel(booking.endDate)}</td><td><span className={`booking-status ${status.toLowerCase()}`}>{status}</span></td><td>{money(bookingAmount(booking), currency)}</td></tr>;
}

function QuickAction({ to, icon, title, subtitle, teal, orange, purple }: { to: string; icon: ReactNode; title: string; subtitle: string; teal?: boolean; orange?: boolean; purple?: boolean }) {
  const tone = teal ? 'teal' : orange ? 'orange' : purple ? 'purple' : '';
  return <Link className="quick-action" to={to}><span className={`quick-icon ${tone}`}>{icon}</span><span><strong>{title}</strong><small>{subtitle}</small></span><ArrowForwardRounded /></Link>;
}

function RevenueChart({ bookings }: { bookings: BookingRecord[] }) {
  const values = Array.from({ length: 6 }, (_, offset) => {
    const target = new Date();
    target.setMonth(target.getMonth() - (5 - offset));
    return bookings.filter((booking) => {
      const date = new Date(booking.payment?.paymentDate || booking.createdAt || 0);
      return booking.payment?.paymentStatus === 'Completed' && date.getMonth() === target.getMonth() && date.getFullYear() === target.getFullYear();
    }).reduce((sum, booking) => sum + bookingAmount(booking), 0);
  });
  const max = Math.max(...values, 1);
  const points = values.map((value, index) => `${8 + index * 18.4},${88 - (value / max) * 68}`).join(' ');
  return <div className="revenue-chart"><svg viewBox="0 0 100 100" preserveAspectRatio="none" role="img" aria-label="Revenue over the last six months"><defs><linearGradient id="revenueFill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1767e8" stopOpacity=".26"/><stop offset="1" stopColor="#1767e8" stopOpacity="0"/></linearGradient></defs><path d={`M ${points} L 100 96 L 8 96 Z`} fill="url(#revenueFill)"/><polyline points={points} fill="none" stroke="#1767e8" strokeWidth="1.4" vectorEffect="non-scaling-stroke"/></svg><div className="chart-months">{values.map((_, index) => { const date = new Date(); date.setMonth(date.getMonth() - (5 - index)); return <span key={index}>{date.toLocaleString('en', { month: 'short' })}</span>; })}</div></div>;
}
