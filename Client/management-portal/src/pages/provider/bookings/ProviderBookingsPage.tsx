import {
  CalendarMonthOutlined,
  CheckCircleOutlineRounded,
  CloseRounded,
  DirectionsCarOutlined,
  ErrorOutlineRounded,
  KeyboardArrowLeftRounded,
  KeyboardArrowRightRounded,
  KeyRounded,
  PersonOutlineRounded,
  RefreshRounded,
  SearchRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState, type ReactNode } from 'react';

import {
  completeProviderBooking,
  getProviderBookings,
  startProviderBooking,
  type ProviderBooking,
  type ProviderBookingStatus,
} from '../../../api/provider/providerBookingsApi';
import { readSession } from '../../../core/session';

import './ProviderBookingsPage.css';

type BookingTab = 'All' | 'Upcoming' | 'Active' | 'Completed' | 'Cancelled';
type TransitionKind = 'start' | 'complete';
type BookingCustomer = NonNullable<ProviderBooking['renter']>;

interface PendingTransition {
  kind: TransitionKind;
  booking: ProviderBooking;
}

const TABS: BookingTab[] = [
  'All',
  'Upcoming',
  'Active',
  'Completed',
  'Cancelled',
];
const PAGE_SIZES = [5, 10, 20] as const;

function bookingTab(status: ProviderBookingStatus): Exclude<BookingTab, 'All'> {
  if (status === 'InProgress') return 'Active';
  if (status === 'Completed') return 'Completed';
  if (status === 'Cancelled') return 'Cancelled';
  return 'Upcoming';
}

function displayStatus(status: ProviderBookingStatus): string {
  return status === 'InProgress' ? 'On Rent' : status;
}

function dateLabel(value?: string): string {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return new Intl.DateTimeFormat('en', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(date);
}

function dateParts(value?: string): { date: string; time: string } {
  if (!value) return { date: '—', time: '' };
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return { date: '—', time: '' };
  return {
    date: new Intl.DateTimeFormat('en', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    }).format(parsed),
    time: new Intl.DateTimeFormat('en', {
      hour: 'numeric',
      minute: '2-digit',
    }).format(parsed),
  };
}

function rentalDays(booking: ProviderBooking): number {
  const start = new Date(booking.startDate || 0);
  const end = new Date(booking.endDate || 0);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  return Math.max(1, Math.ceil((end.getTime() - start.getTime()) / 86_400_000));
}

function money(value: number | undefined, currency: string): string {
  const amount = Number(value ?? 0);
  try {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    }).format(Number.isFinite(amount) ? amount : 0);
  } catch {
    return `${currency} ${Number.isFinite(amount) ? amount.toLocaleString('en') : '0'}`;
  }
}

function vehicleName(booking: ProviderBooking): string {
  const car = booking.carVariant?.car;
  return [car?.brand, car?.model].filter(Boolean).join(' ') || 'Vehicle';
}

function renterName(booking: ProviderBooking): string {
  return booking.renter?.name?.trim() || 'Renter';
}

export default function ProviderBookingsPage() {
  const providerId = readSession()?.user._id ?? '';
  const fallbackCurrency = (readSession()?.user.currency || 'AED').toUpperCase();
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<BookingTab>('All');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<number>(10);
  const [pendingTransition, setPendingTransition] =
    useState<PendingTransition | null>(null);
  const [selectedCustomer, setSelectedCustomer] =
    useState<BookingCustomer | null>(null);
  const [notice, setNotice] = useState<
    { tone: 'success' | 'error'; message: string } | null
  >(null);

  const bookingsQuery = useQuery({
    queryKey: ['provider', providerId, 'bookings'],
    queryFn: () => getProviderBookings(providerId),
    enabled: Boolean(providerId),
  });

  const transitionMutation = useMutation({
    mutationFn: async ({ kind, booking }: PendingTransition) =>
      kind === 'start'
        ? startProviderBooking(booking._id)
        : completeProviderBooking(booking._id),
    onSuccess: async (message) => {
      setNotice({ tone: 'success', message });
      setPendingTransition(null);
      await queryClient.invalidateQueries({ queryKey: ['provider', providerId] });
    },
    onError: (error: Error) => {
      setNotice({ tone: 'error', message: error.message });
      setPendingTransition(null);
    },
  });

  const bookings = bookingsQuery.data ?? [];

  const counts = useMemo(() => {
    const result: Record<BookingTab, number> = {
      All: bookings.length,
      Upcoming: 0,
      Active: 0,
      Completed: 0,
      Cancelled: 0,
    };
    bookings.forEach((booking) => {
      result[bookingTab(booking.status)] += 1;
    });
    return result;
  }, [bookings]);

  const filteredBookings = useMemo(() => {
    const query = search.trim().toLowerCase();
    return [...bookings]
      .filter((booking) => {
        const matchesTab =
          activeTab === 'All' || bookingTab(booking.status) === activeTab;
        const searchable = [
          booking._id,
          renterName(booking),
          booking.renter?.phoneNumber,
          vehicleName(booking),
          booking.carVariant?.registrationNumber,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();
        return matchesTab && (!query || searchable.includes(query));
      })
      .sort((left, right) => {
        if (left.status === 'InProgress' && right.status !== 'InProgress') return -1;
        if (right.status === 'InProgress' && left.status !== 'InProgress') return 1;
        return new Date(left.startDate || 0).getTime() - new Date(right.startDate || 0).getTime();
      });
  }, [activeTab, bookings, search]);

  useEffect(() => {
    setPage(1);
  }, [activeTab, search, pageSize]);

  const pageCount = Math.max(1, Math.ceil(filteredBookings.length / pageSize));
  const currentPage = Math.min(page, pageCount);
  const pageBookings = filteredBookings.slice(
    (currentPage - 1) * pageSize,
    currentPage * pageSize,
  );

  if (bookingsQuery.isPending) {
    return (
      <main className="provider-bookings-state">
        <span className="provider-bookings-spinner" />
        Loading bookings…
      </main>
    );
  }

  if (bookingsQuery.isError) {
    return (
      <main className="provider-bookings-page">
        <section className="provider-bookings-state card">
          <CalendarMonthOutlined />
          <h1>Bookings unavailable</h1>
          <p>{bookingsQuery.error.message}</p>
          <button type="button" onClick={() => void bookingsQuery.refetch()}>
            Try again
          </button>
        </section>
      </main>
    );
  }

  return (
    <main className="provider-bookings-page">
      <section className="provider-bookings-heading">
        <div>
          <h1>Booking Management</h1>
          <p>Track upcoming reservations and manage vehicles currently on rent.</p>
        </div>
        <button
          className="provider-bookings-refresh"
          type="button"
          disabled={bookingsQuery.isFetching}
          onClick={() => void bookingsQuery.refetch()}
        >
          <RefreshRounded />
          {bookingsQuery.isFetching ? 'Refreshing…' : 'Refresh'}
        </button>
      </section>

      {notice?.tone === 'success' && (
        <div className={`provider-bookings-notice ${notice.tone}`} role="status">
          <span>{notice.message}</span>
          <button type="button" aria-label="Dismiss message" onClick={() => setNotice(null)}>
            <CloseRounded />
          </button>
        </div>
      )}

      <section className="provider-bookings-summary" aria-label="Booking summary">
        <SummaryCard icon={<CalendarMonthOutlined />} label="Upcoming" value={counts.Upcoming} tone="blue" />
        <SummaryCard icon={<DirectionsCarOutlined />} label="On Rent" value={counts.Active} tone="orange" />
        <SummaryCard icon={<CheckCircleOutlineRounded />} label="Completed" value={counts.Completed} tone="green" />
        <SummaryCard icon={<CloseRounded />} label="Cancelled" value={counts.Cancelled} tone="red" />
      </section>

      <section className="provider-bookings-panel">
        <div className="provider-bookings-toolbar">
          <div className="provider-bookings-tabs" role="tablist" aria-label="Booking status">
            {TABS.map((tab) => (
              <button
                key={tab}
                type="button"
                role="tab"
                aria-selected={activeTab === tab}
                className={activeTab === tab ? 'active' : ''}
                onClick={() => setActiveTab(tab)}
              >
                {tab}<span>{counts[tab]}</span>
              </button>
            ))}
          </div>

          <label className="provider-bookings-search">
            <SearchRounded />
            <input
              type="search"
              value={search}
              placeholder="Search customer, vehicle or booking…"
              onChange={(event) => setSearch(event.target.value)}
            />
          </label>
        </div>

        {filteredBookings.length === 0 ? (
          <div className="provider-bookings-empty">
            <CalendarMonthOutlined />
            <h2>{bookings.length ? 'No matching bookings' : 'No bookings yet'}</h2>
            <p>
              {bookings.length
                ? 'Try another status tab or search term.'
                : 'New customer reservations will appear here.'}
            </p>
          </div>
        ) : (
          <>
            <div className="provider-bookings-table-wrap">
              <table className="provider-bookings-table">
                <thead>
                  <tr>
                    <th>Booking</th>
                    <th>Customer</th>
                    <th>Vehicle</th>
                    <th>Pickup</th>
                    <th>Return</th>
                    <th>Status</th>
                    <th>Amount</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {pageBookings.map((booking) => (
                    <BookingRow
                      key={booking._id}
                      booking={booking}
                      fallbackCurrency={fallbackCurrency}
                      disabled={transitionMutation.isPending}
                      onViewCustomer={() => {
                        if (booking.renter) setSelectedCustomer(booking.renter);
                      }}
                      onTransition={(kind) => {
                        setNotice(null);
                        setPendingTransition({ kind, booking });
                      }}
                    />
                  ))}
                </tbody>
              </table>
            </div>

            <div className="provider-bookings-mobile-list">
              {pageBookings.map((booking) => (
                <BookingMobileCard
                  key={booking._id}
                  booking={booking}
                  fallbackCurrency={fallbackCurrency}
                  disabled={transitionMutation.isPending}
                  onViewCustomer={() => {
                    if (booking.renter) setSelectedCustomer(booking.renter);
                  }}
                  onTransition={(kind) => {
                    setNotice(null);
                    setPendingTransition({ kind, booking });
                  }}
                />
              ))}
            </div>

            <BookingPagination
              total={filteredBookings.length}
              page={currentPage}
              pageCount={pageCount}
              pageSize={pageSize}
              onPageSizeChange={setPageSize}
              onPageChange={setPage}
            />
          </>
        )}
      </section>

      {pendingTransition && (
        <TransitionDialog
          transition={pendingTransition}
          loading={transitionMutation.isPending}
          onCancel={() => setPendingTransition(null)}
          onConfirm={() => transitionMutation.mutate(pendingTransition)}
        />
      )}

      {notice?.tone === 'error' && (
        <ErrorDialog message={notice.message} onClose={() => setNotice(null)} />
      )}

      {selectedCustomer && (
        <CustomerDetailsDialog
          customer={selectedCustomer}
          onClose={() => setSelectedCustomer(null)}
        />
      )}
    </main>
  );
}

function ErrorDialog({
  message,
  onClose,
}: {
  message: string;
  onClose: () => void;
}) {
  return (
    <div className="provider-bookings-error-backdrop">
      <section
        className="provider-bookings-error-dialog"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="booking-error-title"
        aria-describedby="booking-error-message"
      >
        <button
          className="provider-bookings-error-close"
          type="button"
          aria-label="Close error message"
          onClick={onClose}
        >
          <CloseRounded />
        </button>
        <span className="provider-bookings-error-icon" aria-hidden="true">
          <ErrorOutlineRounded />
        </span>
        <h2 id="booking-error-title">Unable to complete action</h2>
        <p id="booking-error-message">{message}</p>
        <button
          className="provider-bookings-error-confirm"
          type="button"
          autoFocus
          onClick={onClose}
        >
          OK
        </button>
      </section>
    </div>
  );
}

function CustomerDetailsDialog({
  customer,
  onClose,
}: {
  customer: BookingCustomer;
  onClose: () => void;
}) {
  const name = customer.name?.trim() || 'Renter';
  return (
    <div
      className="provider-bookings-customer-backdrop"
      role="presentation"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <section
        className="provider-bookings-customer-dialog"
        role="dialog"
        aria-modal="true"
        aria-labelledby="customer-details-title"
      >
        <button
          className="provider-bookings-customer-dialog-close"
          type="button"
          aria-label="Close customer details"
          onClick={onClose}
        >
          <CloseRounded />
        </button>

        <header className="provider-bookings-customer-profile">
          {customer.profilePicture ? (
            <img src={customer.profilePicture} alt={`${name}'s profile`} />
          ) : (
            <span>{name.charAt(0).toUpperCase()}</span>
          )}
          <div>
            <p>Customer details</p>
            <h2 id="customer-details-title">{name}</h2>
            {customer.username && <small>@{customer.username}</small>}
            <strong className={customer.isVerified ? 'verified' : 'unverified'}>
              {customer.isVerified ? 'Verified renter' : 'Not verified'}
            </strong>
          </div>
        </header>

        <div className="provider-bookings-customer-sections">
          <CustomerSection title="Contact information">
            <CustomerDetail label="Email" value={customer.email} />
            <CustomerDetail label="Phone number" value={customer.phoneNumber} />
            <CustomerDetail label="Location" value={customer.location} />
          </CustomerSection>

          <CustomerSection title="Personal information">
            <CustomerDetail label="Nationality" value={customer.nationality} />
            <CustomerDetail label="Gender" value={customer.gender} />
            <CustomerDetail label="Date of birth" value={dateLabel(customer.birthDate)} />
            <CustomerDetail label="Occupation" value={customer.occupation} />
          </CustomerSection>

          <CustomerSection title="Identity and licence">
            <CustomerDetail label="Driving licence" value={customer.drivingLicenseNumber} />
            <CustomerDetail label="ID card number" value={customer.idCardNumber} />
            <CustomerDetail label="Preferred currency" value={customer.currency?.toUpperCase()} />
          </CustomerSection>
        </div>

        <footer>
          <button type="button" onClick={onClose}>Close</button>
        </footer>
      </section>
    </div>
  );
}

function CustomerSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="provider-bookings-customer-section">
      <h3>{title}</h3>
      <dl>{children}</dl>
    </section>
  );
}

function CustomerDetail({
  label,
  value,
}: {
  label: string;
  value?: string;
}) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value?.trim() || 'Not provided'}</dd>
    </div>
  );
}

function SummaryCard({
  icon,
  label,
  value,
  tone,
}: {
  icon: ReactNode;
  label: string;
  value: number;
  tone: 'blue' | 'orange' | 'green' | 'red';
}) {
  return (
    <article className="provider-bookings-summary-card">
      <span className={tone}>{icon}</span>
      <div><small>{label}</small><strong>{value}</strong></div>
    </article>
  );
}

function BookingRow({
  booking,
  fallbackCurrency,
  disabled,
  onViewCustomer,
  onTransition,
}: {
  booking: ProviderBooking;
  fallbackCurrency: string;
  disabled: boolean;
  onViewCustomer: () => void;
  onTransition: (kind: TransitionKind) => void;
}) {
  const customer = renterName(booking);
  const currency = (booking.payment?.currency || fallbackCurrency).toUpperCase();
  const amount = booking.payment?.amount ?? booking.totalPrice;
  const created = dateParts(booking.createdAt);
  const pickup = dateParts(booking.startDate);
  const returnDate = dateParts(booking.endDate);
  const days = rentalDays(booking);
  const car = booking.carVariant?.car;

  return (
    <tr>
      <td>
        <span className="provider-bookings-reference">#{booking._id.slice(-9).toUpperCase()}</span>
        <small className="provider-bookings-secondary">{created.date}</small>
      </td>
      <td>
        <button
          className="provider-bookings-customer provider-bookings-customer-button"
          type="button"
          onClick={onViewCustomer}
          aria-label={`View ${customer}'s details`}
        >
          {booking.renter?.profilePicture ? (
            <img src={booking.renter.profilePicture} alt="" />
          ) : (
            <span>{customer.charAt(0).toUpperCase()}</span>
          )}
          <div>
            <strong>{customer}</strong>
            <small>{booking.renter?.email || 'No email'}</small>
            <small>{booking.renter?.phoneNumber || 'No phone'}</small>
          </div>
        </button>
      </td>
      <td>
        <div className="provider-bookings-vehicle">
          {booking.carVariant?.images?.[0] ? (
            <img src={booking.carVariant.images[0]} alt="" />
          ) : (
            <span><DirectionsCarOutlined /></span>
          )}
          <div>
            <strong>{vehicleName(booking)}</strong>
            <small>{[car?.year, car?.category].filter(Boolean).join(' · ') || 'Details unavailable'}</small>
            <small className="provider-bookings-registration">{booking.carVariant?.registrationNumber || 'No registration'}</small>
          </div>
        </div>
      </td>
      <td><DateCell value={pickup} /></td>
      <td><DateCell value={returnDate} /></td>
      <td><StatusBadge status={booking.status} /></td>
      <td>
        <strong>{money(amount, currency)}</strong>
        <small className="provider-bookings-secondary">{days ? `${days} ${days === 1 ? 'day' : 'days'}` : 'Duration unavailable'}</small>
      </td>
      <td><BookingAction booking={booking} disabled={disabled} onTransition={onTransition} /></td>
    </tr>
  );
}

function DateCell({ value }: { value: { date: string; time: string } }) {
  return (
    <span className="provider-bookings-date-cell">
      <strong>{value.date}</strong>
      {value.time && <small>{value.time}</small>}
    </span>
  );
}

function BookingPagination({
  total,
  page,
  pageCount,
  pageSize,
  onPageSizeChange,
  onPageChange,
}: {
  total: number;
  page: number;
  pageCount: number;
  pageSize: number;
  onPageSizeChange: (value: number) => void;
  onPageChange: (value: number) => void;
}) {
  const first = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const last = Math.min(page * pageSize, total);
  const visiblePages = Array.from(
    { length: Math.min(3, pageCount) },
    (_, index) => {
      if (pageCount <= 3) return index + 1;
      if (page <= 2) return index + 1;
      if (page >= pageCount - 1) return pageCount - 2 + index;
      return page - 1 + index;
    },
  );

  return (
    <footer className="provider-bookings-footer">
      <span>Showing {first} to {last} of {total} bookings</span>
      <div className="provider-bookings-pagination">
        <label>
          <span className="sr-only">Bookings per page</span>
          <select
            value={pageSize}
            onChange={(event) => onPageSizeChange(Number(event.target.value))}
          >
            {PAGE_SIZES.map((size) => <option key={size} value={size}>{size} per page</option>)}
          </select>
        </label>
        <button type="button" aria-label="Previous page" disabled={page === 1} onClick={() => onPageChange(Math.max(1, page - 1))}><KeyboardArrowLeftRounded /></button>
        {visiblePages.map((pageNumber) => (
          <button
            key={pageNumber}
            type="button"
            className={pageNumber === page ? 'active' : ''}
            aria-current={pageNumber === page ? 'page' : undefined}
            onClick={() => onPageChange(pageNumber)}
          >
            {pageNumber}
          </button>
        ))}
        <button type="button" aria-label="Next page" disabled={page === pageCount} onClick={() => onPageChange(Math.min(pageCount, page + 1))}><KeyboardArrowRightRounded /></button>
      </div>
    </footer>
  );
}

function BookingMobileCard({
  booking,
  fallbackCurrency,
  disabled,
  onViewCustomer,
  onTransition,
}: {
  booking: ProviderBooking;
  fallbackCurrency: string;
  disabled: boolean;
  onViewCustomer: () => void;
  onTransition: (kind: TransitionKind) => void;
}) {
  const currency = (booking.payment?.currency || fallbackCurrency).toUpperCase();
  return (
    <article className="provider-bookings-mobile-card">
      <header>
        <span>#{booking._id.slice(-7).toUpperCase()}</span>
        <StatusBadge status={booking.status} />
      </header>
      <div className="provider-bookings-mobile-main">
        <span className="provider-bookings-mobile-image">
          {booking.carVariant?.images?.[0] ? <img src={booking.carVariant.images[0]} alt="" /> : <DirectionsCarOutlined />}
        </span>
        <div><h2>{vehicleName(booking)}</h2><p>{booking.carVariant?.registrationNumber || 'No registration'}</p></div>
      </div>
      <button
        className="provider-bookings-mobile-customer"
        type="button"
        onClick={onViewCustomer}
      >
        <PersonOutlineRounded />{renterName(booking)}
        <span>View details</span>
      </button>
      <dl>
        <div><dt>Pickup</dt><dd>{dateLabel(booking.startDate)}</dd></div>
        <div><dt>Return</dt><dd>{dateLabel(booking.endDate)}</dd></div>
        <div><dt>Amount</dt><dd>{money(booking.payment?.amount ?? booking.totalPrice, currency)}</dd></div>
      </dl>
      <BookingAction booking={booking} disabled={disabled} onTransition={onTransition} />
    </article>
  );
}

function StatusBadge({ status }: { status: ProviderBookingStatus }) {
  return (
    <span className={`provider-bookings-status ${status.toLowerCase()}`}>
      {displayStatus(status)}
    </span>
  );
}

function BookingAction({
  booking,
  disabled,
  onTransition,
}: {
  booking: ProviderBooking;
  disabled: boolean;
  onTransition: (kind: TransitionKind) => void;
}) {
  if (booking.status === 'Confirmed') {
    return <button className="provider-bookings-action start" type="button" disabled={disabled} onClick={() => onTransition('start')}><KeyRounded />Start Rental</button>;
  }
  if (booking.status === 'InProgress') {
    return <button className="provider-bookings-action complete" type="button" disabled={disabled} onClick={() => onTransition('complete')}><CheckCircleOutlineRounded />Complete Rental</button>;
  }
  return <span className="provider-bookings-no-action">No action required</span>;
}

function TransitionDialog({
  transition,
  loading,
  onCancel,
  onConfirm,
}: {
  transition: PendingTransition;
  loading: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  const starting = transition.kind === 'start';
  return (
    <div className="provider-bookings-dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !loading) onCancel(); }}>
      <section className="provider-bookings-dialog" role="dialog" aria-modal="true" aria-labelledby="booking-transition-title">
        <button className="provider-bookings-dialog-close" type="button" aria-label="Close" disabled={loading} onClick={onCancel}><CloseRounded /></button>
        <span className={starting ? 'start' : 'complete'}>{starting ? <KeyRounded /> : <CheckCircleOutlineRounded />}</span>
        <h2 id="booking-transition-title">{starting ? 'Start this rental?' : 'Complete this rental?'}</h2>
        <p>
          {starting
            ? `Confirm that ${renterName(transition.booking)} has collected the ${vehicleName(transition.booking)}.`
            : `Confirm that the ${vehicleName(transition.booking)} has been returned.`}
        </p>
        <div className="provider-bookings-dialog-details">
          <small>Booking</small><strong>#{transition.booking._id.slice(-7).toUpperCase()}</strong>
          <small>Rental dates</small><strong>{dateLabel(transition.booking.startDate)} – {dateLabel(transition.booking.endDate)}</strong>
        </div>
        <footer>
          <button type="button" disabled={loading} onClick={onCancel}>Cancel</button>
          <button className={starting ? 'start' : 'complete'} type="button" disabled={loading} onClick={onConfirm}>
            {loading ? 'Saving…' : starting ? 'Start Rental' : 'Complete Rental'}
          </button>
        </footer>
      </section>
    </div>
  );
}
