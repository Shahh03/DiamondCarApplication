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
import { useQuery } from '@tanstack/react-query';
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
  type FleetAvailability,
  type ProviderFleetBooking,
  type ProviderFleetVehicle,
} from '../../../api/provider/providerFleetApi';
import { readSession } from '../../../core/session';

import './ProviderFleetPage.css';

const PAGE_SIZE = 5;

type AvailabilityFilter = 'all' | FleetAvailability;

function bookingVehicleId(booking: ProviderFleetBooking): string | undefined {
  if (typeof booking.carVariant === 'string') return booking.carVariant;
  return booking.carVariant?._id;
}

function startOfUtcDay(value: Date): number {
  const date = new Date(value);
  date.setUTCHours(0, 0, 0, 0);
  return date.getTime();
}

function activeRentalVehicleIds(bookings: ProviderFleetBooking[]): Set<string> {
  const today = startOfUtcDay(new Date());

  return new Set(
    bookings
      .filter((booking) => {
        if (
          booking.status !== 'Confirmed' ||
          !booking.startDate ||
          !booking.endDate
        ) {
          return false;
        }

        const start = new Date(booking.startDate);
        const end = new Date(booking.endDate);
        if (
          Number.isNaN(start.getTime()) ||
          Number.isNaN(end.getTime())
        ) {
          return false;
        }

        return startOfUtcDay(start) <= today && startOfUtcDay(end) >= today;
      })
      .map(bookingVehicleId)
      .filter((id): id is string => Boolean(id)),
  );
}

function vehicleAvailability(
  vehicle: ProviderFleetVehicle,
  onRentIds: Set<string>,
): FleetAvailability {
  if (onRentIds.has(vehicle._id)) return 'on-rent';
  return vehicle.isAvailable === false ? 'unavailable' : 'available';
}

function availabilityLabel(availability: FleetAvailability): string {
  if (availability === 'on-rent') return 'On Rent';
  if (availability === 'unavailable') return 'Unavailable';
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

  const [search, setSearch] = useState(searchParams.get('search') ?? '');
  const [availability, setAvailability] =
    useState<AvailabilityFilter>('all');
  const [brand, setBrand] = useState('all');
  const [category, setCategory] = useState('all');
  const [year, setYear] = useState('all');
  const [page, setPage] = useState(1);
  const [selectedVehicle, setSelectedVehicle] =
    useState<ProviderFleetVehicle | null>(null);

  const fleetQuery = useQuery({
    queryKey: ['provider', providerId, 'fleet'],
    queryFn: () => getProviderFleet(providerId),
    enabled: Boolean(providerId),
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
  const onRentIds = useMemo(
    () => activeRentalVehicleIds(fleetQuery.data?.bookings ?? []),
    [fleetQuery.data?.bookings],
  );

  const counts = useMemo(() => {
    const result = {
      all: vehicles.length,
      available: 0,
      'on-rent': 0,
      unavailable: 0,
    };

    for (const vehicle of vehicles) {
      result[vehicleAvailability(vehicle, onRentIds)] += 1;
    }

    return result;
  }, [onRentIds, vehicles]);

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
      const currentAvailability = vehicleAvailability(vehicle, onRentIds);
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
        (availability === 'all' || availability === currentAvailability) &&
        (brand === 'all' || vehicle.car?.brand === brand) &&
        (category === 'all' || vehicle.car?.category === category) &&
        (year === 'all' || String(vehicle.car?.year) === year)
      );
    });
  }, [availability, category, brand, onRentIds, search, vehicles, year]);

  const pageCount = Math.max(1, Math.ceil(filteredVehicles.length / PAGE_SIZE));
  const currentPage = Math.min(page, pageCount);
  const pageVehicles = filteredVehicles.slice(
    (currentPage - 1) * PAGE_SIZE,
    currentPage * PAGE_SIZE,
  );

  const hasFilters =
    Boolean(search.trim()) ||
    availability !== 'all' ||
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
    setAvailability('all');
    setBrand('all');
    setCategory('all');
    setYear('all');
    setPage(1);
    setSearchParams({}, { replace: true });
  }

  function changeAvailability(next: AvailabilityFilter) {
    setAvailability(next);
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
          <p>Manage your vehicles, availability and pricing.</p>
        </div>

        <button
          className="provider-fleet-add"
          type="button"
          disabled
          title="Vehicle creation will be implemented next"
        >
          <AddRounded />
          Add Vehicle
        </button>
      </section>

      <section className="provider-fleet-kpis" aria-label="Fleet summary">
        <FleetKpi
          label="Total Vehicles"
          value={counts.all}
          icon={<DirectionsCarOutlined />}
          tone="blue"
          active={availability === 'all'}
          onClick={() => changeAvailability('all')}
        />
        <FleetKpi
          label="Available"
          value={counts.available}
          icon={<CheckCircleOutlineRounded />}
          tone="teal"
          active={availability === 'available'}
          onClick={() => changeAvailability('available')}
        />
        <FleetKpi
          label="On Rent"
          value={counts['on-rent']}
          icon={<KeyRounded />}
          tone="blue"
          active={availability === 'on-rent'}
          onClick={() => changeAvailability('on-rent')}
        />
        <FleetKpi
          label="Unavailable"
          value={counts.unavailable}
          icon={<BlockOutlined />}
          tone="orange"
          active={availability === 'unavailable'}
          onClick={() => changeAvailability('unavailable')}
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

        <div className="provider-fleet-tabs" role="group" aria-label="Availability">
          {(
            [
              ['all', 'All'],
              ['available', 'Available'],
              ['on-rent', 'On Rent'],
              ['unavailable', 'Unavailable'],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              className={availability === value ? 'active' : ''}
              onClick={() => changeAvailability(value)}
            >
              {label}
              <span>{counts[value]}</span>
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
                    <th>Availability</th>
                    <th>Photos</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {pageVehicles.map((vehicle) => {
                    const currentAvailability = vehicleAvailability(
                      vehicle,
                      onRentIds,
                    );

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
                          <AvailabilityBadge availability={currentAvailability} />
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
                const currentAvailability = vehicleAvailability(vehicle, onRentIds);

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
                      <AvailabilityBadge availability={currentAvailability} />
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
          availability={vehicleAvailability(selectedVehicle, onRentIds)}
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
  tone: 'blue' | 'teal' | 'orange';
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
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  allLabel: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="provider-fleet-filter">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        <option value="all">{allLabel}</option>
        {options.map((option) => (
          <option key={option} value={option}>{option}</option>
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

function AvailabilityBadge({
  availability,
}: {
  availability: FleetAvailability;
}) {
  return (
    <span className={`provider-fleet-badge ${availability}`}>
      {availabilityLabel(availability)}
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
  availability,
  currency,
  onClose,
}: {
  vehicle: ProviderFleetVehicle;
  availability: FleetAvailability;
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

          <AvailabilityBadge availability={availability} />

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
