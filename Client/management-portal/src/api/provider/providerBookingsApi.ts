import { apiClient, apiErrorMessage } from '../../core/apiClient';

export type ProviderBookingStatus =
  | 'Confirmed'
  | 'InProgress'
  | 'Completed'
  | 'Cancelled';

export interface ProviderBooking {
  _id: string;
  status: ProviderBookingStatus;
  startDate?: string;
  endDate?: string;
  totalPrice?: number;
  startedAt?: string;
  completedAt?: string;
  createdAt?: string;
  renter?: {
    _id?: string;
    name?: string;
    username?: string;
    email?: string;
    phoneNumber?: string;
    profilePicture?: string;
    nationality?: string;
    birthDate?: string;
    occupation?: string;
    gender?: string;
    isVerified?: boolean;
    drivingLicenseNumber?: string;
    idCardNumber?: string;
    location?: string;
    currency?: string;
  };
  carVariant?: {
    _id?: string;
    color?: string;
    registrationNumber?: string;
    images?: string[];
    car?: {
      brand?: string;
      model?: string;
      year?: number;
      category?: string;
    };
  };
  payment?: {
    amount?: number;
    currency?: string;
    paymentMethod?: string;
    paymentStatus?: 'Completed' | 'Failed' | 'Refunded';
    paymentDate?: string;
  };
}

interface BookingTransitionResponse {
  message?: string;
  booking?: Pick<
    ProviderBooking,
    'status' | 'startDate' | 'endDate' | 'startedAt' | 'completedAt'
  > & { _id?: string };
}

function unwrapBookings(value: unknown): ProviderBooking[] {
  if (Array.isArray(value)) return value as ProviderBooking[];
  if (!value || typeof value !== 'object') return [];

  const object = value as Record<string, unknown>;
  for (const key of ['bookings', 'data']) {
    if (Array.isArray(object[key])) return object[key] as ProviderBooking[];
  }
  return [];
}

export async function getProviderBookings(
  providerId: string,
): Promise<ProviderBooking[]> {
  try {
    const response = await apiClient.get(
      `/booking/getbookingForProvider/${providerId}`,
    );
    return unwrapBookings(response.data);
  } catch (error) {
    throw new Error(
      apiErrorMessage(error, 'Could not load provider bookings.'),
    );
  }
}

export async function startProviderBooking(
  bookingId: string,
): Promise<string> {
  try {
    const response = await apiClient.put<BookingTransitionResponse>(
      `/booking/start/${bookingId}`,
    );
    return response.data.message || 'Rental started successfully.';
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not start the rental.'));
  }
}

export async function completeProviderBooking(
  bookingId: string,
): Promise<string> {
  try {
    const response = await apiClient.put<BookingTransitionResponse>(
      `/booking/complete/${bookingId}`,
    );
    return response.data.message || 'Rental completed successfully.';
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not complete the rental.'));
  }
}
