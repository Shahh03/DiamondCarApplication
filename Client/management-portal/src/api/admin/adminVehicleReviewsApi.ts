import { apiClient, apiErrorMessage } from '../../core/apiClient';
import type {
  ProviderFleetCar,
  VehicleApprovalStatus,
} from '../provider/providerFleetApi';

export interface AdminVehicleReview {
  _id: string;
  approvalStatus: VehicleApprovalStatus;
  submittedAt?: string;
  reviewedAt?: string;
  rejectionReason?: string;
  color?: string;
  registrationNumber?: string;
  rentalPricePerDay?: number;
  depositAmount?: number;
  images?: string[];
  insuranceDetails?: {
    insuranceCompany?: string;
    policyNumber?: string;
    expiryDate?: string;
  };
  car?: ProviderFleetCar;
  provider?: {
    _id?: string;
    companyName?: string;
    email?: string;
    profilePicture?: string;
    isVerified?: boolean;
    status?: string;
    contactPerson?: {
      name?: string;
      email?: string;
      phoneNumber?: string;
    };
    address?: {
      city?: string;
      country?: string;
    };
  };
  reviewedBy?: {
    username?: string;
    email?: string;
  };
}

interface ReviewResponse {
  message?: string;
  carVariant?: AdminVehicleReview;
}

export async function getAdminVehicleReviews(
  status: VehicleApprovalStatus,
): Promise<AdminVehicleReview[]> {
  try {
    const response = await apiClient.get('/admin/carVariant/reviews', {
      params: { status },
    });
    return Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not load vehicle reviews.'));
  }
}

export async function reviewAdminVehicle(
  vehicleId: string,
  decision: 'Approved' | 'Rejected',
  rejectionReason = '',
): Promise<string> {
  try {
    const response = await apiClient.put<ReviewResponse>(
      `/admin/carVariant/${vehicleId}/review`,
      { decision, rejectionReason },
    );
    return response.data.message || 'Vehicle review saved.';
  } catch (error) {
    throw new Error(apiErrorMessage(error, 'Could not review the vehicle.'));
  }
}
