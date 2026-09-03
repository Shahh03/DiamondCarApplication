
import {
  AddRounded,
  BlockOutlined,
  CheckCircleOutlineRounded,
  ChevronRightRounded,
  CloseRounded,
  DirectionsCarOutlined,
  EditOutlined,
  FilterAltOffRounded,
  ImageOutlined,
  KeyboardArrowLeftRounded,
  KeyboardArrowRightRounded,
  KeyRounded,
  SearchRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  useEffect,
  useMemo,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { Link, useSearchParams } from 'react-router-dom';

import {
  getProviderFleet,
  submitProviderFleetVehicleForReview,
  type FleetCurrentStatus,
  type FleetListingStatus,
  type ProviderFleetBooking,
  type ProviderFleetVehicle,
  type VehicleApprovalStatus,
} from '../../../api/provider/providerFleetApi';
import { readSession } from '../../../core/session';

import './ProviderFleetPage.css';

const PAGE_SIZE = 5;

type CurrentStatusFilter = 'all' | FleetCurrentStatus;
type ListingFilter = 'all' | FleetListingStatus;

function bookingVehicleId(booking: ProviderFleetBooking): string | undefined {
  if (typeof booking.carVariant === 'string') return booking.carVariant;
  return booking.carVariant?._id;
}

function utcDay(value: string | Date): number | null {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

function currentStatusesByVehicle(
  bookings: ProviderFleetBooking[],
): Map<string, FleetCurrentStatus> {
  const statuses = new Map<string, FleetCurrentStatus>();
  const today = utcDay(new Date());

  for (const booking of bookings) {
    const vehicleId = bookingVehicleId(booking);
    if (!vehicleId) continue;

    if (booking.status === 'InProgress') {
      statuses.set(vehicleId, 'on-rent');
      continue;
    }

    if (booking.status !== 'Confirmed' || statuses.get(vehicleId) === 'on-rent') {
      continue;
    }

    const start = booking.startDate ? utcDay(booking.startDate) : null;
    const end = booking.endDate ? utcDay(booking.endDate) : null;
    if (today != null && start != null && end != null && start <= today && today <= end) {
      statuses.set(vehicleId, 'unavailable');
    }
  }

  return statuses;
}

function vehicleCurrentStatus(
  vehicle: ProviderFleetVehicle,
  statuses: Map<string, FleetCurrentStatus>,
): FleetCurrentStatus {
  return statuses.get(vehicle._id) ?? 'available';
}

function vehicleListingStatus(
  vehicle: ProviderFleetVehicle,
): FleetListingStatus {
  return vehicle.isAvailable !== false ? 'listed' : 'unlisted';
}

function currentStatusLabel(status: FleetCurrentStatus): string {
  if (status === 'on-rent') return 'On Rent';
  if (status === 'unavailable') return 'Unavailable';
  return 'Available';
}

function formatMoney(value: number | undefined, currency: string): string {
  const amount = Number(value ?? 0);

  try {
    return new Intl.NumberFormat('en', {
      style: 'currency',
      currency,
      maximumFractionDigits: 0,
    }).format(Number.isFinite(amount) ? amount : 0);
  } catch {
    return `AED ${Number.isFinite(amount) ? amount.toLocaleString('en') : '0'}`;
  }
}

function formatDate(value?: string): string {
  if (!value) return 'Not provided';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not provided';

  return new Intl.DateTimeFormat('en', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(date);
}

function vehicleName(vehicle: ProviderFleetVehicle): string {
  return [vehicle.car?.brand, vehicle.car?.model]
    .filter(Boolean)
    .join(' ') || 'Vehicle';
}

function uniqueSorted(values: Array<string | number | undefined>): string[] {
  return Array.from(
    new Set(
      values
        .filter((value): value is string | number => value != null)
        .map(String)
        .filter(Boolean),
    ),
  ).sort((left, right) => left.localeCompare(right, undefined, { numeric: true }));
}

export default function ProviderFleetPage() {
  const providerId = readSession()?.user._id ?? '';
  const currency = (readSession()?.user.currency || 'AED').toUpperCase();
  const [searchParams, setSearchParams] = useSearchParams();
  const queryClient = useQueryClient();

  const [search, setSearch] = useState(searchParams.get('search') ?? '');
  const [listing, setListing] = useState<ListingFilter>('all');
  const [currentStatus, setCurrentStatus] =
    useState<CurrentStatusFilter>('all');
  const [brand, setBrand] = useState('all');
  const [category, setCategory] = useState('all');
  const [year, setYear] = useState('all');
  const [page, setPage] = useState(1);
  const [selectedVehicle, setSelectedVehicle] =
    useState<ProviderFleetVehicle | null>(null);
  const [actionError, setActionError] = useState('');

  const fleetQuery = useQuery({
    queryKey: ['provider', providerId, 'fleet'],
    queryFn: () => getProviderFleet(providerId),
    enabled: Boolean(providerId),
  });

  const resubmitMutation = useMutation({
    mutationFn: submitProviderFleetVehicleForReview,
    onSuccess: async () => {
      setActionError('');
      await queryClient.invalidateQueries({ queryKey: ['provider', providerId] });
    },
    onError: (error: Error) => setActionError(error.message),
  });

  useEffect(() => {
    setSearch(searchParams.get('search') ?? '');
    setPage(1);
  }, [searchParams]);

  useEffect(() => {
    if (!selectedVehicle) return undefined;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === 'Escape') setSelectedVehicle(null);
    }

    document.addEventListener('keydown', closeOnEscape);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', closeOnEscape);
    };
  }, [selectedVehicle]);

  const vehicles = fleetQuery.data?.vehicles ?? [];
  const currentStatusByVehicle = useMemo(
    () => currentStatusesByVehicle(fleetQuery.data?.bookings ?? []),
    [fleetQuery.data?.bookings],
  );

  const currentStatusCounts = useMemo(() => {
    const result = {
      all: vehicles.length,
      available: 0,
      'on-rent': 0,
      unavailable: 0,
    };

    for (const vehicle of vehicles) {
      result[vehicleCurrentStatus(vehicle, currentStatusByVehicle)] += 1;
    }

    return result;
  }, [currentStatusByVehicle, vehicles]);

  const listingCounts = useMemo(() => {
    const result = { all: vehicles.length, listed: 0, unlisted: 0 };

    for (const vehicle of vehicles) {
      result[vehicleListingStatus(vehicle)] += 1;
    }

    return result;
  }, [vehicles]);

  const brands = useMemo(
    () => uniqueSorted(vehicles.map((vehicle) => vehicle.car?.brand)),
    [vehicles],
  );
  const categories = useMemo(
    () => uniqueSorted(vehicles.map((vehicle) => vehicle.car?.category)),
    [vehicles],
  );
  const years = useMemo(
    () =>
      uniqueSorted(vehicles.map((vehicle) => vehicle.car?.year)).sort(
        (left, right) => Number(right) - Number(left),
      ),
    [vehicles],
  );

  const filteredVehicles = useMemo(() => {
    const query = search.trim().toLowerCase();

    return vehicles.filter((vehicle) => {
      const vehicleStatus = vehicleCurrentStatus(vehicle, currentStatusByVehicle);
      const vehicleListing = vehicleListingStatus(vehicle);
      const searchable = [
        vehicle.car?.brand,
        vehicle.car?.model,
        vehicle.car?.year,
        vehicle.car?.category,
        vehicle.registrationNumber,
        vehicle.color,
      ]
        .filter((value) => value != null)
        .join(' ')
        .toLowerCase();

      return (
        (!query || searchable.includes(query)) &&
        (listing === 'all' || listing === vehicleListing) &&
        (currentStatus === 'all' || currentStatus === vehicleStatus) &&
        (brand === 'all' || vehicle.car?.brand === brand) &&
        (category === 'all' || vehicle.car?.category === category) &&
        (year === 'all' || String(vehicle.car?.year) === year)
      );
    });
  }, [brand, category, currentStatus, currentStatusByVehicle, listing, search, vehicles, year]);

  const pageCount = Math.max(1, Math.ceil(filteredVehicles.length / PAGE_SIZE));
  const currentPage = Math.min(page, pageCount);
  const pageVehicles = filteredVehicles.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  const hasFilters =
    Boolean(search.trim()) ||
    listing !== 'all' ||
    currentStatus !== 'all' ||
    brand !== 'all' ||
    category !== 'all' ||
    year !== 'all';

  function updateSearch(value: string) {
    setSearch(value);
    setPage(1);

    const nextParams = new URLSearchParams(searchParams);
    if (value.trim()) nextParams.set('search', value);
    else nextParams.delete('search');
    setSearchParams(nextParams, { replace: true });
  }

  function clearFilters() {
    setSearch('');
    setListing('all');
    setCurrentStatus('all');
    setBrand('all');
    setCategory('all');
    setYear('all');
    setPage(1);
    setSearchParams({}, { replace: true });
  }

  function changeCurrentStatus(next: CurrentStatusFilter) {
    setCurrentStatus(next);
    setPage(1);
  }

  function changeListing(next: ListingFilter) {
    setListing(next);
    setPage(1);
  }

  if (fleetQuery.isPending) {
    return <FleetLoadingState />;
  }

  if (fleetQuery.isError) {
    return (
      <main className="provider-fleet-page">
        <div className="provider-fleet-state">
          <span><DirectionsCarOutlined /></span>
          <h1>Fleet unavailable</h1>
          <p>{fleetQuery.error.message}</p>
          <button type="button" onClick={() => void fleetQuery.refetch()}>
            Try again
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="provider-fleet-page">
      <section className="provider-fleet-heading">
        <div>
          <h1>Fleet Management</h1>
          <p>Manage vehicle listings, current status and pricing.</p>
        </div>

        <Link
          className="provider-fleet-add"
          to="/provider/fleet/add"
        >
          <AddRounded />
          Add Vehicle
        </Link>
      </section>

      {actionError && <div className="provider-fleet-action-error" role="alert">{actionError}</div>}

      <section className="provider-fleet-kpis" aria-label="Fleet summary">
        <FleetKpi
          label="Total Vehicles"
          value={currentStatusCounts.all}
          icon={<DirectionsCarOutlined />}
          tone="blue"
          active={currentStatus === 'all'}
          onClick={() => changeCurrentStatus('all')}
        />
        <FleetKpi
          label="Available"
          value={currentStatusCounts.available}
          icon={<CheckCircleOutlineRounded />}
          tone="teal"
          active={currentStatus === 'available'}
          onClick={() => changeCurrentStatus('available')}
        />
        <FleetKpi
          label="On Rent"
          value={currentStatusCounts['on-rent']}
          icon={<KeyRounded />}
          tone="orange"
          active={currentStatus === 'on-rent'}
          onClick={() => changeCurrentStatus('on-rent')}
        />
        <FleetKpi
          label="Unavailable"
          value={currentStatusCounts.unavailable}
          icon={<BlockOutlined />}
          tone="red"
          active={currentStatus === 'unavailable'}
          onClick={() => changeCurrentStatus('unavailable')}
        />
      </section>

      <section className="provider-fleet-panel">
        <div className="provider-fleet-toolbar">
          <label className="provider-fleet-search">
            <SearchRounded />
            <input
              type="search"
              value={search}
              placeholder="Search by brand, model or registration..."
              onChange={(event) => updateSearch(event.target.value)}
            />
          </label>

          <div className="provider-fleet-selects">
            <FilterSelect
              label="Current status"
              value={currentStatus}
              options={['available', 'on-rent', 'unavailable']}
              allLabel="All Statuses"
              optionLabel={(option) => currentStatusLabel(option as FleetCurrentStatus)}
              onChange={(value) => changeCurrentStatus(value as CurrentStatusFilter)}
            />
            <FilterSelect
              label="Brand"
              value={brand}
              options={brands}
              allLabel="All Brands"
              onChange={(value) => {
                setBrand(value);
                setPage(1);
              }}
            />
            <FilterSelect
              label="Category"
              value={category}
              options={categories}
              allLabel="All Categories"
              onChange={(value) => {
                setCategory(value);
                setPage(1);
              }}
            />
            <FilterSelect
              label="Year"
              value={year}
              options={years}
              allLabel="All Years"
              onChange={(value) => {
                setYear(value);
                setPage(1);
              }}
            />
          </div>
        </div>

        <div className="provider-fleet-tabs" role="group" aria-label="Listing status">
          {(
            [
              ['all', 'All'],
              ['listed', 'Listed'],
              ['unlisted', 'Unlisted'],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={listing === value ? 'active' : ''}
              onClick={() => changeListing(value)}
            >
              {label}
              <span>{listingCounts[value]}</span>
            </button>
          ))}

          {hasFilters && (
            <button
              className="provider-fleet-clear"
              type="button"
              onClick={clearFilters}
            >
              <FilterAltOffRounded />
              Clear filters
            </button>
          )}
        </div>

        {vehicles.length === 0 ? (
          <FleetEmptyState
            title="Your fleet is empty"
            message="Vehicles added to your provider account will appear here."
          />
        ) : pageVehicles.length === 0 ? (
          <FleetEmptyState
            title="No matching vehicles"
            message="Try changing or clearing your search and filters."
            actionLabel="Clear filters"
            onAction={clearFilters}
          />
        ) : (
          <>
            <div className="provider-fleet-table-wrap">
              <table className="provider-fleet-table">
                <thead>
                  <tr>
                    <th>Vehicle</th>
                    <th>Registration</th>
                    <th>Color</th>
                    <th>Price / Day</th>
                    <th>Approval</th>
                    <th>Listing</th>
                    <th>Current Status</th>
                    <th>Photos</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {pageVehicles.map((vehicle) => {
                    const vehicleStatus = vehicleCurrentStatus(
                      vehicle,
                      currentStatusByVehicle,
                    );
                    const vehicleListing = vehicleListingStatus(vehicle);

                    return (
                      <tr key={vehicle._id}>
                        <td>
                          <VehicleIdentity vehicle={vehicle} />
                        </td>
                        <td>
                          <span className="provider-fleet-registration">
                            {vehicle.registrationNumber || 'Not provided'}
                          </span>
                        </td>
                        <td>
                          <ColorLabel color={vehicle.color} />
                        </td>
                        <td className="provider-fleet-money">
                          {formatMoney(vehicle.rentalPricePerDay, currency)}
                        </td>
                        <td>
                          <ApprovalBadge status={vehicle.approvalStatus} />
                        </td>
                        <td>
                          <ListingBadge listing={vehicleListing} />
                        </td>
                        <td>
                          <CurrentStatusBadge status={vehicleStatus} />
                        </td>
                        <td>
                          <span className="provider-fleet-photo-count">
                            <ImageOutlined />
                            {vehicle.images?.length ?? 0}
                          </span>
                        </td>
                        <td>
                          <div className="provider-fleet-actions">
                            <button
                              className="provider-fleet-view"
                              type="button"
                              onClick={() => setSelectedVehicle(vehicle)}
                            >
                              View
                              <ChevronRightRounded />
                            </button>
                            <Link
                              className="provider-fleet-edit"
                              to={`/provider/fleet/${vehicle._id}/edit`}
                            >
                              <EditOutlined />
                              Edit
                            </Link>
                            {vehicle.approvalStatus === 'Rejected' && (
                              <button
                                className="provider-fleet-resubmit"
                                type="button"
                                disabled={resubmitMutation.isPending}
                                onClick={() => resubmitMutation.mutate(vehicle._id)}
                              >
                                Resubmit
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div className="provider-fleet-mobile-list">
              {pageVehicles.map((vehicle) => {
                const vehicleStatus = vehicleCurrentStatus(
                  vehicle,
                  currentStatusByVehicle,
                );
                const vehicleListing = vehicleListingStatus(vehicle);

                return (
                  <article
                    key={vehicle._id}
                    className="provider-fleet-mobile-card"
                  >
                    <VehicleThumbnail vehicle={vehicle} />
                    <span className="provider-fleet-mobile-copy">
                      <strong>{vehicleName(vehicle)}</strong>
                      <small>
                        {vehicle.car?.year || 'Year not provided'} ·{' '}
                        {vehicle.registrationNumber || 'No registration'}
                      </small>
                      <span className="provider-fleet-mobile-statuses">
                        <ApprovalBadge status={vehicle.approvalStatus} />
                        <ListingBadge listing={vehicleListing} />
                        <CurrentStatusBadge status={vehicleStatus} />
                      </span>
                      <b>{formatMoney(vehicle.rentalPricePerDay, currency)} / day</b>
                    </span>
                    <span className="provider-fleet-mobile-actions">
                      <button
                        type="button"
                        onClick={() => setSelectedVehicle(vehicle)}
                      >
                        View
                      </button>
                      <Link to={`/provider/fleet/${vehicle._id}/edit`}>
                        <EditOutlined />
                        Edit
                      </Link>
                    </span>
                  </article>
                );
              })}
            </div>

            <footer className="provider-fleet-footer">
              <span>
                Showing {(currentPage - 1) * PAGE_SIZE + 1}–
                {Math.min(currentPage * PAGE_SIZE, filteredVehicles.length)} of{' '}
                {filteredVehicles.length} vehicles
              </span>

              <div className="provider-fleet-pagination">
                <button
                  type="button"
                  aria-label="Previous page"
                  disabled={currentPage === 1}
                  onClick={() => setPage((value) => Math.max(1, value - 1))}
                >
                  <KeyboardArrowLeftRounded />
                </button>
                <span>Page {currentPage} of {pageCount}</span>
                <button
                  type="button"
                  aria-label="Next page"
                  disabled={currentPage === pageCount}
                  onClick={() =>
                    setPage((value) => Math.min(pageCount, value + 1))
                  }
                >
                  <KeyboardArrowRightRounded />
                </button>
              </div>
            </footer>
          </>
        )}
      </section>

      {fleetQuery.isFetching && !fleetQuery.isPending && (
        <div className="provider-fleet-refreshing" role="status">
          Refreshing fleet…
        </div>
      )}

      {selectedVehicle && (
        <VehicleDrawer
          vehicle={selectedVehicle}
          listing={vehicleListingStatus(selectedVehicle)}
          currentStatus={vehicleCurrentStatus(
            selectedVehicle,
            currentStatusByVehicle,
          )}
          currency={currency}
          onClose={() => setSelectedVehicle(null)}
        />
      )}
    </main>
  );
}

function FleetKpi({
  label,
  value,
  icon,
  tone,
  active,
  onClick,
}: {
  label: string;
  value: number;
  icon: ReactNode;
  tone: 'blue' | 'teal' | 'orange' | 'red';
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      className={`provider-fleet-kpi ${active ? 'active' : ''}`}
      type="button"
      onClick={onClick}
    >
      <span className={`provider-fleet-kpi-icon ${tone}`}>{icon}</span>
      <span>
        <small>{label}</small>
        <strong>{value}</strong>
      </span>
    </button>
  );
}

function FilterSelect({
  label,
  value,
  options,
  allLabel,
  optionLabel = (option) => option,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  allLabel: string;
  optionLabel?: (option: string) => string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="provider-fleet-filter">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        <option value="all">{allLabel}</option>
        {options.map((option) => (
          <option key={option} value={option}>{optionLabel(option)}</option>
        ))}
      </select>
    </label>
  );
}

function VehicleThumbnail({ vehicle }: { vehicle: ProviderFleetVehicle }) {
  const image = vehicle.images?.find((value) => value?.trim());

  return (
    <span className="provider-fleet-thumbnail">
      {image ? (
        <img src={image} alt="" />
      ) : (
        <DirectionsCarOutlined />
      )}
    </span>
  );
}

function VehicleIdentity({ vehicle }: { vehicle: ProviderFleetVehicle }) {
  return (
    <div className="provider-fleet-vehicle">
      <VehicleThumbnail vehicle={vehicle} />
      <span>
        <strong>{vehicleName(vehicle)}</strong>
        <small>
          {[vehicle.car?.year, vehicle.car?.category]
            .filter(Boolean)
            .join(' · ') || 'Details not provided'}
        </small>
      </span>
    </div>
  );
}

function ColorLabel({ color }: { color?: string }) {
  const safeColor = color?.trim() || 'Not provided';
  const dotColor = color?.trim() || '#cbd5e1';

  return (
    <span className="provider-fleet-color">
      <i style={{ '--vehicle-color': dotColor } as CSSProperties} />
      {safeColor}
    </span>
  );
}

function CurrentStatusBadge({
  status,
}: {
  status: FleetCurrentStatus;
}) {
  return (
    <span className={`provider-fleet-badge ${status}`}>
      {currentStatusLabel(status)}
    </span>
  );
}

function ListingBadge({
  listing,
}: {
  listing: FleetListingStatus;
}) {
  return (
    <span className={`provider-fleet-listing ${listing}`}>
      {listing === 'listed' ? 'Listed' : 'Unlisted'}
    </span>
  );
}

function ApprovalBadge({
  status,
}: {
  status?: VehicleApprovalStatus;
}) {
  const currentStatus = status ?? 'Approved';
  return (
    <span className={`provider-fleet-approval ${currentStatus.toLowerCase()}`}>
      {currentStatus === 'Pending' ? 'Pending Review' : currentStatus}
    </span>
  );
}

function FleetEmptyState({
  title,
  message,
  actionLabel,
  onAction,
}: {
  title: string;
  message: string;
  actionLabel?: string;
  onAction?: () => void;
}) {
  return (
    <div className="provider-fleet-empty">
      <span><DirectionsCarOutlined /></span>
      <h2>{title}</h2>
      <p>{message}</p>
      {actionLabel && onAction && (
        <button type="button" onClick={onAction}>{actionLabel}</button>
      )}
    </div>
  );
}

function FleetLoadingState() {
  return (
    <main className="provider-fleet-page" aria-busy="true">
      <div className="provider-fleet-heading provider-fleet-skeleton-heading">
        <div><i /><i /></div><i />
      </div>
      <div className="provider-fleet-kpis">
        {Array.from({ length: 4 }, (_, index) => (
          <div className="provider-fleet-kpi provider-fleet-skeleton" key={index} />
        ))}
      </div>
      <div className="provider-fleet-panel provider-fleet-loading-panel">
        {Array.from({ length: 6 }, (_, index) => <i key={index} />)}
      </div>
    </main>
  );
}

function VehicleDrawer({
  vehicle,
  listing,
  currentStatus,
  currency,
  onClose,
}: {
  vehicle: ProviderFleetVehicle;
  listing: FleetListingStatus;
  currentStatus: FleetCurrentStatus;
  currency: string;
  onClose: () => void;
}) {
  const images = (vehicle.images ?? []).filter(
    (value): value is string => Boolean(value?.trim()),
  );
  const [activeImageIndex, setActiveImageIndex] = useState(0);
  const activeImage = images[activeImageIndex];
  const hasMultipleImages = images.length > 1;

  useEffect(() => {
    setActiveImageIndex(0);
  }, [vehicle._id]);

  useEffect(() => {
    if (!hasMultipleImages) return undefined;

    function changeImageWithKeyboard(event: KeyboardEvent) {
      if (event.key === 'ArrowLeft') {
        setActiveImageIndex((index) =>
          index === 0 ? images.length - 1 : index - 1,
        );
      }

      if (event.key === 'ArrowRight') {
        setActiveImageIndex((index) =>
          index === images.length - 1 ? 0 : index + 1,
        );
      }
    }

    document.addEventListener('keydown', changeImageWithKeyboard);

    return () => {
      document.removeEventListener('keydown', changeImageWithKeyboard);
    };
  }, [hasMultipleImages, images.length]);

  function showPreviousImage() {
    setActiveImageIndex((index) =>
      index === 0 ? images.length - 1 : index - 1,
    );
  }

  function showNextImage() {
    setActiveImageIndex((index) =>
      index === images.length - 1 ? 0 : index + 1,
    );
  }

  return (
    <div className="provider-fleet-drawer-layer">
      <button
        className="provider-fleet-drawer-backdrop"
        type="button"
        aria-label="Close vehicle details"
        onClick={onClose}
      />

      <aside
        className="provider-fleet-drawer"
        role="dialog"
        aria-modal="true"
        aria-labelledby="provider-fleet-drawer-title"
      >
        <header>
          <div>
            <small>Vehicle details</small>
            <h2 id="provider-fleet-drawer-title">{vehicleName(vehicle)}</h2>
          </div>
          <button type="button" aria-label="Close" onClick={onClose}>
            <CloseRounded />
          </button>
        </header>

        <div className="provider-fleet-drawer-image">
          {activeImage ? (
            <img
              src={activeImage}
              alt={`${vehicleName(vehicle)} photo ${activeImageIndex + 1}`}
            />
          ) : (
            <DirectionsCarOutlined />
          )}

          <CurrentStatusBadge status={currentStatus} />

          {hasMultipleImages && (
            <>
              <button
                className="provider-fleet-gallery-arrow previous"
                type="button"
                aria-label="Previous vehicle photo"
                onClick={showPreviousImage}
              >
                <KeyboardArrowLeftRounded />
              </button>

              <button
                className="provider-fleet-gallery-arrow next"
                type="button"
                aria-label="Next vehicle photo"
                onClick={showNextImage}
              >
                <KeyboardArrowRightRounded />
              </button>
            </>
          )}

          {images.length > 0 && (
            <span className="provider-fleet-gallery-counter">
              {activeImageIndex + 1} / {images.length}
            </span>
          )}
        </div>

        {hasMultipleImages && (
          <div
            className="provider-fleet-gallery-thumbnails"
            aria-label="Vehicle photos"
          >
            {images.map((image, index) => (
              <button
                key={`${image}-${index}`}
                className={index === activeImageIndex ? 'active' : ''}
                type="button"
                aria-label={`Show vehicle photo ${index + 1}`}
                aria-current={index === activeImageIndex ? 'true' : undefined}
                onClick={() => setActiveImageIndex(index)}
              >
                <img src={image} alt="" />
              </button>
            ))}
          </div>
        )}

        <div className="provider-fleet-prices">
          <span>
            <small>Price per day</small>
            <strong>{formatMoney(vehicle.rentalPricePerDay, currency)}</strong>
          </span>
          <span>
            <small>Deposit</small>
            <strong>{formatMoney(vehicle.depositAmount, currency)}</strong>
          </span>
        </div>

        <DrawerSection title="Listing review">
          <div className="provider-fleet-review-details">
            <ApprovalBadge status={vehicle.approvalStatus} />
            <ListingBadge listing={listing} />
            <p>
              {vehicle.approvalStatus === 'Pending'
                ? 'This vehicle is waiting for admin approval and is not visible to renters.'
                : vehicle.approvalStatus === 'Rejected'
                  ? vehicle.rejectionReason || 'The admin requested changes before approval.'
                  : listing === 'listed'
                    ? 'This vehicle is approved and visible to renters.'
                    : 'This vehicle is approved but the provider has unlisted it.'}
            </p>
          </div>
        </DrawerSection>

        <DrawerSection title="Vehicle information">
          <dl className="provider-fleet-details-grid">
            <Detail label="Registration" value={vehicle.registrationNumber} />
            <Detail label="Color" value={vehicle.color} />
            <Detail label="Year" value={vehicle.car?.year} />
            <Detail label="Category" value={vehicle.car?.category} />
            <Detail label="Transmission" value={vehicle.car?.transmission} />
            <Detail label="Fuel type" value={vehicle.car?.fuelType} />
            <Detail label="Seats" value={vehicle.car?.seats} />
            <Detail label="Photos" value={vehicle.images?.length ?? 0} />
          </dl>
        </DrawerSection>

        <DrawerSection title="Insurance">
          <dl className="provider-fleet-details-list">
            <Detail
              label="Company"
              value={vehicle.insuranceDetails?.insuranceCompany}
            />
            <Detail
              label="Policy number"
              value={vehicle.insuranceDetails?.policyNumber}
            />
            <Detail
              label="Expiry date"
              value={formatDate(vehicle.insuranceDetails?.expiryDate)}
            />
          </dl>
        </DrawerSection>

        {Boolean(vehicle.car?.features?.length) && (
          <DrawerSection title="Features">
            <div className="provider-fleet-features">
              {vehicle.car?.features?.map((feature) => (
                <span key={feature}>{feature}</span>
              ))}
            </div>
          </DrawerSection>
        )}
      </aside>
    </div>
  );
}

function DrawerSection({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <section className="provider-fleet-drawer-section">
      <h3>{title}</h3>
      {children}
    </section>
  );
}

function Detail({
  label,
  value,
}: {
  label: string;
  value: string | number | undefined;
}) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value === undefined || value === '' ? 'Not provided' : value}</dd>
    </div>
  );
}
