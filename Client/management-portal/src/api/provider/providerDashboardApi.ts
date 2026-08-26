import { apiClient, apiErrorMessage } from '../../core/apiClient';

export interface ProviderRecord {
  _id: string;
  companyName?: string;
  username?: string;
  profilePicture?: string;
  currency?: string;
}

export interface CarVariantRecord {
  _id: string;
  isAvailable?: boolean;
  color?: string;
  images?: string[];
  car?: {
    brand?: string;
    model?: string;
    year?: number;
  };
}

export interface BookingRecord {
  _id: string;
  renter?: {
    _id?: string;
    name?: string;
    username?: string;
    profilePicture?: string;
  };
  carVariant?: CarVariantRecord;
  startDate?: string;
  endDate?: string;
  totalPrice?: number;
  status?: 'Confirmed' | 'Cancelled' | 'Completed';
  createdAt?: string;
  payment?: {
    amount?: number;
    currency?: string;
    paymentStatus?: 'Completed' | 'Failed' | 'Refunded';
    paymentDate?: string;
    refundDetails?: { refundedAmount?: number };
  };
}

export interface ProviderDashboardData {
  provider: ProviderRecord;
  fleet: CarVariantRecord[];
  bookings: BookingRecord[];
}

function asObject(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function unwrapObject(value: unknown, keys: string[]): Record<string, unknown> {
  const object = asObject(value);
  if (!object) throw new Error('The server returned invalid information.');

  for (const key of keys) {
    const nested = asObject(object[key]);
    if (nested) return nested;
  }
  return object;
}

function unwrapArray(value: unknown, keys: string[]): unknown[] {
  if (Array.isArray(value)) return value;
  const object = asObject(value);
  if (!object) return [];
  for (const key of keys) {
    if (Array.isArray(object[key])) return object[key] as unknown[];
  }
  return [];
}

export async function getProviderDashboard(
  providerId: string,
): Promise<ProviderDashboardData> {
  try {
    const [providerResponse, fleetResponse, bookingsResponse] = await Promise.all([
      apiClient.get(`/provider/get/${providerId}`),
      apiClient.get(`/carVariant/getAllCarsForProvider/${providerId}`),
      apiClient.get(`/booking/getbookingForProvider/${providerId}`),
    ]);

    const provider = unwrapObject(providerResponse.data, ['provider', 'data']);
    if (!provider._id) {
      throw new Error('The server returned incomplete provider information.');
    }

    return {
      provider: provider as unknown as ProviderRecord,
      fleet: unwrapArray(fleetResponse.data, ['fleet', 'vehicles', 'data']).map(
        (item) => item as CarVariantRecord,
      ),
      bookings: unwrapArray(bookingsResponse.data, ['bookings', 'data']).map(
        (item) => item as BookingRecord,
      ),
    };
  } catch (error) {
    if (error instanceof Error && !('response' in error)) throw error;
    throw new Error(apiErrorMessage(error, 'Could not load the provider dashboard.'));
  }
}