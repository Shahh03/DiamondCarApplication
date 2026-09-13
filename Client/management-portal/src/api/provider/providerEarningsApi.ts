import { apiClient, apiErrorMessage } from '../../core/apiClient';

export interface ProviderEarningsSummary {
  rentalRevenue: number;
  depositsCollected: number;
  grossCollected: number;
  refunds: number;
  netEarnings: number;
  paymentCount: number;
  refundCount: number;
}

export interface ProviderEarningsChartPoint {
  period: string;
  collected: number;
  refunds: number;
  net: number;
}

export interface ProviderEarningsTransaction {
  id: string;
  type: 'Payment' | 'Refund';
  date: string;
  amount: number;
  paymentMethod?: string;
  renterName: string;
  reference?: string;
  reason?: string;
  bookingId?: string | null;
  carVariantId?: string | null;
  vehicle: string;
  registrationNumber?: string;
}

export interface ProviderEarningsData {
  providerId: string;
  currency: string;
  range: {
    from: string;
    to: string;
    groupBy: 'day' | 'month';
  };
  summary: ProviderEarningsSummary;
  chart: ProviderEarningsChartPoint[];
  transactions: ProviderEarningsTransaction[];
}

export interface ProviderEarningsRange {
  from: string;
  to: string;
  limit?: number;
}

export async function getProviderEarnings(
  providerId: string,
  range: ProviderEarningsRange,
): Promise<ProviderEarningsData> {
  try {
    const response = await apiClient.get<ProviderEarningsData>(
      `/provider/earnings/${providerId}`,
      {
        params: {
          from: range.from,
          to: range.to,
          limit: range.limit ?? 100,
        },
      },
    );

    if (!response.data?.summary || !Array.isArray(response.data.transactions)) {
      throw new Error('The server returned incomplete earnings information.');
    }

    return response.data;
  } catch (error) {
    if (error instanceof Error && !('response' in error)) throw error;
    throw new Error(apiErrorMessage(error, 'Could not load provider earnings.'));
  }
}
