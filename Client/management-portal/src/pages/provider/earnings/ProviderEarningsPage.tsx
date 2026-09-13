import {
  AccountBalanceWalletOutlined,
  CalendarMonthOutlined,
  CreditCardRounded,
  DirectionsCarOutlined,
  DownloadRounded,
  PaymentsOutlined,
  ReceiptLongOutlined,
  RefreshRounded,
  ReplayRounded,
  SearchRounded,
  TrendingUpRounded,
} from '@mui/icons-material';
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState, type ReactNode } from 'react';

import {
  getProviderEarnings,
  type ProviderEarningsChartPoint,
  type ProviderEarningsTransaction,
} from '../../../api/provider/providerEarningsApi';
import { readSession } from '../../../core/session';

import './ProviderEarningsPage.css';

type RangePreset = 'month' | '30days' | '90days' | 'year' | 'custom';
type TransactionFilter = 'All' | 'Payment' | 'Refund';

const PAGE_SIZE = 10;

function inputDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function presetDates(preset: Exclude<RangePreset, 'custom'>) {
  const now = new Date();
  const from = new Date(now);

  if (preset === 'month') from.setDate(1);
  if (preset === '30days') from.setDate(now.getDate() - 29);
  if (preset === '90days') from.setDate(now.getDate() - 89);
  if (preset === 'year') {
    from.setMonth(0);
    from.setDate(1);
  }

  return { from: inputDate(from), to: inputDate(now) };
}

function startIso(value: string): string {
  return new Date(`${value}T00:00:00.000Z`).toISOString();
}

function endIso(value: string): string {
  return new Date(`${value}T23:59:59.999Z`).toISOString();
}

function money(value: number, currency: string): string {
  try {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    }).format(Number(value) || 0);
  } catch {
    return `${currency} ${(Number(value) || 0).toLocaleString('en')}`;
  }
}

function dateLabel(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('en', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function periodLabel(point: ProviderEarningsChartPoint, groupBy: 'day' | 'month') {
  const value = groupBy === 'month' ? `${point.period}-01` : point.period;
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.getTime())) return point.period;
  return new Intl.DateTimeFormat('en',
    groupBy === 'month'
      ? { month: 'short', year: '2-digit', timeZone: 'UTC' }
      : { day: 'numeric', month: 'short', timeZone: 'UTC' },
  ).format(date);
}

function csvCell(value: unknown): string {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

export default function ProviderEarningsPage() {
  const providerId = readSession()?.user._id ?? '';
  const initialRange = presetDates('month');
  const [preset, setPreset] = useState<RangePreset>('month');
  const [from, setFrom] = useState(initialRange.from);
  const [to, setTo] = useState(initialRange.to);
  const [transactionFilter, setTransactionFilter] =
    useState<TransactionFilter>('All');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const invalidRange = !from || !to || from > to;
  const earningsQuery = useQuery({
    queryKey: ['provider', providerId, 'earnings', from, to],
    queryFn: () =>
      getProviderEarnings(providerId, {
        from: startIso(from),
        to: endIso(to),
        limit: 100,
      }),
    enabled: Boolean(providerId) && !invalidRange,
  });

  const data = earningsQuery.data;
  const currency = (data?.currency || readSession()?.user.currency || 'AED').toUpperCase();

  const filteredTransactions = useMemo(() => {
    const query = search.trim().toLowerCase();
    return (data?.transactions ?? []).filter((transaction) => {
      const matchesType =
        transactionFilter === 'All' || transaction.type === transactionFilter;
      const searchable = [
        transaction.reference,
        transaction.renterName,
        transaction.vehicle,
        transaction.registrationNumber,
        transaction.bookingId,
        transaction.paymentMethod,
      ]
        .filter(Boolean)
        .join(' ')
        .toLowerCase();
      return matchesType && (!query || searchable.includes(query));
    });
  }, [data?.transactions, search, transactionFilter]);

  useEffect(() => setPage(1), [search, transactionFilter, from, to]);

  const pageCount = Math.max(1, Math.ceil(filteredTransactions.length / PAGE_SIZE));
  const currentPage = Math.min(page, pageCount);
  const pageTransactions = filteredTransactions.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  const chartMax = Math.max(
    1,
    ...(data?.chart ?? []).flatMap((point) => [point.collected, point.refunds]),
  );

  function applyPreset(nextPreset: Exclude<RangePreset, 'custom'>) {
    const next = presetDates(nextPreset);
    setPreset(nextPreset);
    setFrom(next.from);
    setTo(next.to);
  }

  function exportTransactions() {
    if (!filteredTransactions.length) return;
    const rows = [
      ['Date', 'Type', 'Reference', 'Customer', 'Vehicle', 'Registration', 'Method', 'Amount', 'Currency'],
      ...filteredTransactions.map((transaction) => [
        transaction.date,
        transaction.type,
        transaction.reference,
        transaction.renterName,
        transaction.vehicle,
        transaction.registrationNumber,
        transaction.paymentMethod,
        transaction.amount,
        currency,
      ]),
    ];
    const csv = rows.map((row) => row.map(csvCell).join(',')).join('\n');
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
    const link = document.createElement('a');
    link.href = url;
    link.download = `diamondcar-earnings-${from}-${to}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  }

  if (earningsQuery.isPending && !invalidRange) {
    return (
      <main className="provider-earnings-state">
        <span className="provider-earnings-spinner" />
        Loading earnings…
      </main>
    );
  }

  return (
    <main className="provider-earnings-page">
      <header className="provider-earnings-heading">
        <div>
          <h1>Earnings</h1>
          <p>Track collected payments, refunds and net revenue.</p>
        </div>
        <div className="provider-earnings-heading-actions">
          <button
            type="button"
            className="provider-earnings-export"
            disabled={!filteredTransactions.length}
            onClick={exportTransactions}
          >
            <DownloadRounded /> Export CSV
          </button>
          <button
            type="button"
            className="provider-earnings-refresh"
            disabled={earningsQuery.isFetching || invalidRange}
            onClick={() => void earningsQuery.refetch()}
          >
            <RefreshRounded />
            {earningsQuery.isFetching ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      <section className="provider-earnings-range" aria-label="Earnings date range">
        <div className="provider-earnings-presets">
          {([
            ['month', 'This month'],
            ['30days', 'Last 30 days'],
            ['90days', 'Last 90 days'],
            ['year', 'This year'],
          ] as const).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={preset === value ? 'active' : ''}
              onClick={() => applyPreset(value)}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="provider-earnings-dates">
          <label><span>From</span><input type="date" value={from} max={to} onChange={(event) => { setFrom(event.target.value); setPreset('custom'); }} /></label>
          <label><span>To</span><input type="date" value={to} min={from} max={inputDate(new Date())} onChange={(event) => { setTo(event.target.value); setPreset('custom'); }} /></label>
        </div>
      </section>

      {invalidRange && (
        <div className="provider-earnings-range-error" role="alert">
          Select a valid date range where From is before To.
        </div>
      )}

      {earningsQuery.isError && (
        <section className="provider-earnings-error" role="alert">
          <ReplayRounded />
          <div><strong>Earnings could not be loaded</strong><span>{earningsQuery.error.message}</span></div>
          <button type="button" onClick={() => void earningsQuery.refetch()}>Try again</button>
        </section>
      )}

      {data && !invalidRange && (
        <>
          <section className="provider-earnings-summary" aria-label="Earnings summary">
            <EarningsCard tone="green" icon={<TrendingUpRounded />} label="Net earnings" value={money(data.summary.netEarnings, currency)} helper="Collected minus refunds" />
            <EarningsCard tone="blue" icon={<PaymentsOutlined />} label="Gross collected" value={money(data.summary.grossCollected, currency)} helper={`${data.summary.paymentCount} successful payments`} />
            <EarningsCard tone="purple" icon={<AccountBalanceWalletOutlined />} label="Rental revenue" value={money(data.summary.rentalRevenue, currency)} helper="Booking charges collected" />
            <EarningsCard tone="red" icon={<ReplayRounded />} label="Refunds" value={money(data.summary.refunds, currency)} helper={`${data.summary.refundCount} refunded payments`} />
          </section>

          <section className="provider-earnings-insight">
            <span><CreditCardRounded /></span>
            <div><small>Deposits collected</small><strong>{money(data.summary.depositsCollected, currency)}</strong></div>
            <p>Deposit amounts included in gross collected payments for this period.</p>
          </section>

          <section className="provider-earnings-chart-card">
            <header>
              <div><h2>Revenue overview</h2><p>Payments and refunds by {data.range.groupBy}.</p></div>
              <div className="provider-earnings-legend"><span className="collected">Collected</span><span className="refunded">Refunded</span></div>
            </header>
            {data.chart.length ? (
              <div className="provider-earnings-chart-scroll">
                <div className="provider-earnings-chart">
                  {data.chart.map((point) => (
                    <div className="provider-earnings-chart-point" key={point.period}>
                      <div className="provider-earnings-chart-values">
                        <div className={`provider-earnings-bar collected${point.collected ? '' : ' empty'}`} style={{ height: point.collected ? `${Math.max(3, (point.collected / chartMax) * 100)}%` : 0 }} title={`Collected: ${money(point.collected, currency)}`} />
                        <div className={`provider-earnings-bar refunded${point.refunds ? '' : ' empty'}`} style={{ height: point.refunds ? `${Math.max(3, (point.refunds / chartMax) * 100)}%` : 0 }} title={`Refunded: ${money(point.refunds, currency)}`} />
                      </div>
                      <strong>{money(point.net, currency)}</strong>
                      <small>{periodLabel(point, data.range.groupBy)}</small>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="provider-earnings-chart-empty"><TrendingUpRounded /><p>No financial activity in this period.</p></div>
            )}
          </section>

          <section className="provider-earnings-transactions">
            <header>
              <div><h2>Transactions</h2><p>Every payment and refund recorded in this period.</p></div>
              <label className="provider-earnings-search"><SearchRounded /><input type="search" value={search} placeholder="Search transaction…" onChange={(event) => setSearch(event.target.value)} /></label>
            </header>
            <div className="provider-earnings-tabs" role="tablist" aria-label="Transaction type">
              {(['All', 'Payment', 'Refund'] as const).map((filter) => {
                const count = filter === 'All' ? data.transactions.length : data.transactions.filter((item) => item.type === filter).length;
                return <button key={filter} type="button" role="tab" aria-selected={transactionFilter === filter} className={transactionFilter === filter ? 'active' : ''} onClick={() => setTransactionFilter(filter)}>{filter}<span>{count}</span></button>;
              })}
            </div>

            {!filteredTransactions.length ? (
              <div className="provider-earnings-empty"><ReceiptLongOutlined /><h3>No matching transactions</h3><p>Try another type, search term or date range.</p></div>
            ) : (
              <>
                <div className="provider-earnings-table-wrap">
                  <table className="provider-earnings-table">
                    <thead><tr><th>Date</th><th>Transaction</th><th>Customer</th><th>Vehicle</th><th>Method</th><th>Amount</th></tr></thead>
                    <tbody>{pageTransactions.map((transaction) => <TransactionRow key={transaction.id} transaction={transaction} currency={currency} />)}</tbody>
                  </table>
                </div>
                <div className="provider-earnings-mobile-list">{pageTransactions.map((transaction) => <TransactionCard key={transaction.id} transaction={transaction} currency={currency} />)}</div>
                <footer className="provider-earnings-footer">
                  <span>Showing {(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, filteredTransactions.length)} of {filteredTransactions.length}</span>
                  <div><button type="button" disabled={currentPage === 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>Previous</button><span>Page {currentPage} of {pageCount}</span><button type="button" disabled={currentPage === pageCount} onClick={() => setPage((value) => Math.min(pageCount, value + 1))}>Next</button></div>
                </footer>
              </>
            )}
          </section>
        </>
      )}
    </main>
  );
}

function EarningsCard({ tone, icon, label, value, helper }: { tone: 'green' | 'blue' | 'purple' | 'red'; icon: ReactNode; label: string; value: string; helper: string }) {
  return <article className={`provider-earnings-card ${tone}`}><span>{icon}</span><div><small>{label}</small><strong>{value}</strong><p>{helper}</p></div></article>;
}

function TransactionRow({ transaction, currency }: { transaction: ProviderEarningsTransaction; currency: string }) {
  return <tr><td><strong>{dateLabel(transaction.date)}</strong></td><td><span className={`provider-earnings-type ${transaction.type.toLowerCase()}`}>{transaction.type}</span><small className="provider-earnings-reference">{transaction.reference || 'No reference'}</small></td><td><strong>{transaction.renterName}</strong><small>Booking {transaction.bookingId ? `#${transaction.bookingId.slice(-8).toUpperCase()}` : '—'}</small></td><td><div className="provider-earnings-vehicle"><DirectionsCarOutlined /><span><strong>{transaction.vehicle}</strong><small>{transaction.registrationNumber || 'No registration'}</small></span></div></td><td>{transaction.paymentMethod || '—'}</td><td><strong className={`provider-earnings-amount ${transaction.type.toLowerCase()}`}>{transaction.amount > 0 ? '+' : ''}{money(transaction.amount, currency)}</strong>{transaction.reason && <small>{transaction.reason}</small>}</td></tr>;
}

function TransactionCard({ transaction, currency }: { transaction: ProviderEarningsTransaction; currency: string }) {
  return <article className="provider-earnings-transaction-card"><header><span className={`provider-earnings-type ${transaction.type.toLowerCase()}`}>{transaction.type}</span><strong className={`provider-earnings-amount ${transaction.type.toLowerCase()}`}>{transaction.amount > 0 ? '+' : ''}{money(transaction.amount, currency)}</strong></header><h3>{transaction.vehicle}</h3><p>{transaction.renterName} · {transaction.registrationNumber || 'No registration'}</p><dl><div><dt>Date</dt><dd>{dateLabel(transaction.date)}</dd></div><div><dt>Method</dt><dd>{transaction.paymentMethod || '—'}</dd></div><div><dt>Reference</dt><dd>{transaction.reference || '—'}</dd></div></dl></article>;
}
