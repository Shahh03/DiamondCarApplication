import { apiClient, apiErrorMessage } from '../../core/apiClient';

export type FleetAvailability = 'available' | 'on-rent' | 'unavailable';
export type VehicleApprovalStatus = 'Pending' | 'Approved' | 'Rejected';

export interface ProviderFleetCar {
  _id: string;
  brand: string;
  model: string;
  year: number;
  category: string;
  transmission: 'Manual' | 'Automatic';
  fuelType: 'Petrol' | 'Diesel' | 'Electric' | 'Hybrid';
  seats: number;
  features?: string[];
}

export interface ProviderFleetVehicle {
  _id: string;
  provider?: string;
  car?: ProviderFleetCar;
  color?: string;
  registrationNumber?: string;
  rentalPricePerDay?: number;
  depositAmount?: number;
  isAvailable?: boolean;
  isListed?: boolean;
  approvalStatus?: VehicleApprovalStatus;
  submittedAt?: string;
  reviewedAt?: string;
  rejectionReason?: string;
  images?: string[];
  imagePublicIds?: string[];
  insuranceDetails?: {
    insuranceCompany?: string;
    policyNumber?: string;
    expiryDate?: string;
  };
  createdAt?: string;
  updatedAt?: string;
}

export interface ProviderFleetBooking {
  _id: string;
  carVariant?: string | { _id?: string };
  startDate?: string;
  endDate?: string;
  status?: 'Confirmed' | 'InProgress' | 'Cancelled' | 'Completed';
}

export interface ProviderFleetData {
  vehicles: ProviderFleetVehicle[];
  bookings: ProviderFleetBooking[];
}

export interface UpdateProviderFleetVehicleInput {
  color: string;
  registrationNumber: string;
  rentalPricePerDay: number;
  depositAmount: number;
  isAvailable: boolean;
  insuranceDetails: {
    insuranceCompany?: string;
    policyNumber?: string;
    expiryDate?: string;
  };
}

export interface CreateProviderFleetVehicleInput {
  provider: string;
  car: string;
  color: string;
  registrationNumber: string;
  rentalPricePerDay: number;
  depositAmount: number;
  insuranceDetails: {
    insuranceCompany: string;
    policyNumber: string;
    expiryDate: string;
  };
}

interface VehicleMutationResponse {
  message?: string;
  carVariant?: ProviderFleetVehicle;
}

interface VehicleImagesResponse {
  message?: string;
  images?: string[];
  imagePublicIds?: string[];
}

function unwrapArray(value: unknown, keys: string[]): unknown[] {
  if (Array.isArray(value)) return value;

  if (!value || typeof value !== 'object') return [];
  const object = value as Record<string, unknown>;

  for (const key of keys) {
    const nested = object[key];
    if (Array.isArray(nested)) return nested;
  }

  return [];
}

export async function getProviderFleet(
  providerId: string,
): Promise<ProviderFleetData> {
  try {
    const [vehiclesResponse, bookingsResponse] = await Promise.all([
      apiClient.get(`/carVariant/getAllCarsForProvider/${providerId}`),
      apiClient.get(`/booking/getbookingForProvider/${providerId}`),
    ]);

    return {
      vehicles: unwrapArray(vehiclesResponse.data, [
        'vehicles',
        'fleet',
        'data',
      ]) as ProviderFleetVehicle[],
      bookings: unwrapArray(bookingsResponse.data, [
        'bookings',
        'data',
      ]) as ProviderFleetBooking[],
    };
  } catch (error) {
    throw new Error(
      apiErrorMessage(error, 'Could not load your fleet.'),
    );
  }
}

export async function getCarCatalog(): Promise<ProviderFleetCar[]> {
  try {
    const response = await apiClient.get('/car/getAllCars');
    return unwrapArray(response.data, ['cars', 'data']) as ProviderFleetCar[];
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not load the car catalogue.'));
  }
}

export async function createProviderFleetVehicle(
  input: CreateProviderFleetVehicleInput,
): Promise<ProviderFleetVehicle> {
  try {
    const response = await apiClient.post<VehicleMutationResponse>(
      '/carVariant/create',
      input,
    );
    if (!response.data.carVariant?._id) {
      throw new Error('The server returned incomplete vehicle information.');
    }
    return response.data.carVariant;
  } catch (error) {
    if (error instanceof Error && !('response' in error)) throw error;
    throw new Error(apiErrorMessage(error, 'Could not submit the vehicle.'));
  }
}

export async function submitProviderFleetVehicleForReview(
  vehicleId: string,
): Promise<ProviderFleetVehicle> {
  try {
    const response = await apiClient.put<VehicleMutationResponse>(
      `/carVariant/${vehicleId}/submit-review`,
    );
    if (!response.data.carVariant?._id) {
      throw new Error('The server returned incomplete vehicle information.');
    }
    return response.data.carVariant;
  } catch (error) {
    if (error instanceof Error && !('response' in error)) throw error;
    throw new Error(
      apiErrorMessage(error, 'Could not submit the vehicle for review.'),
    );
  }
}

export async function updateProviderFleetVehicle(
  vehicleId: string,
  input: UpdateProviderFleetVehicleInput,
): Promise<ProviderFleetVehicle> {
  try {
    const response = await apiClient.put<VehicleMutationResponse>(
      `/carVariant/update/${vehicleId}`,
      input,
    );

    if (!response.data.carVariant?._id) {
      throw new Error('The server returned incomplete vehicle information.');
    }

    return response.data.carVariant;
  } catch (error) {
    if (error instanceof Error && !('response' in error)) throw error;
    throw new Error(apiErrorMessage(error, 'Could not update the vehicle.'));
  }
}

export async function uploadProviderFleetVehicleImages(
  vehicleId: string,
  files: File[],
): Promise<string[]> {
  const formData = new FormData();
  files.forEach((file) => formData.append('files', file));

  try {
    const response = await apiClient.post<VehicleImagesResponse>(
      `/carVariant/uploadCarVariantImages/${vehicleId}`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    );

    return response.data.images ?? [];
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not upload vehicle photos.'));
  }
}

export async function removeProviderFleetVehicleImage(
  vehicleId: string,
  imageUrl: string,
): Promise<string[]> {
  try {
    const response = await apiClient.delete<VehicleImagesResponse>(
      `/carVariant/${vehicleId}/image`,
      { data: { imageUrl } },
    );

    return response.data.images ?? [];
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not remove the vehicle photo.'));
  }
}

export async function reorderProviderFleetVehicleImages(
  vehicleId: string,
  orderedImageUrls: string[],
): Promise<string[]> {
  try {
    const response = await apiClient.put<VehicleImagesResponse>(
      `/carVariant/${vehicleId}/images/order`,
      { orderedImageUrls },
    );

    return response.data.images ?? [];
  } catch (error) {
    throw new Error(
      apiErrorMessage(error, 'Could not save the vehicle photo order.'),
    );
  }
}
