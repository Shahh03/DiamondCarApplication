import { apiClient } from '../../core/apiClient';

export type NotificationType =
  | 'BookingConfirmed'
  | 'BookingCancelled'
  | 'ProviderApproved'
  | 'ProviderRejected'
  | 'VehicleApproved'
  | 'VehicleRejected';

export interface PortalNotification {
  _id: string;
  type: NotificationType;
  title: string;
  message: string;
  actionUrl?: string;
  isRead: boolean;
  readAt?: string | null;
  createdAt: string;
}

export interface NotificationListResponse {
  notifications: PortalNotification[];
  unreadCount: number;
}

export async function getNotifications(options?: {
  limit?: number;
  unreadOnly?: boolean;
}): Promise<NotificationListResponse> {
  const response = await apiClient.get<NotificationListResponse>('/notification', {
    params: options,
  });
  return response.data;
}

export async function markNotificationRead(notificationId: string) {
  const response = await apiClient.patch<{ notification: PortalNotification }>(
    `/notification/${notificationId}/read`,
  );
  return response.data.notification;
}

export async function markAllNotificationsRead() {
  const response = await apiClient.patch<{ updatedCount: number }>(
    '/notification/read-all',
  );
  return response.data;
}
