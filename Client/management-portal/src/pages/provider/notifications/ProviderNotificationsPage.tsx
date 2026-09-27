import {
  CalendarMonthRounded,
  CheckCircleRounded,
  DirectionsCarRounded,
  NotificationsNoneRounded,
  TaskAltRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

import {
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type PortalNotification,
} from '../../../api/notifications/notificationApi';
import { notificationQueryKey } from '../../../components/notifications/ProviderNotificationBell';

import './ProviderNotificationsPage.css';

function iconFor(type: PortalNotification['type']) {
  if (type.startsWith('Booking')) return <CalendarMonthRounded />;
  if (type.startsWith('Vehicle')) return <DirectionsCarRounded />;
  if (type === 'ProviderApproved') return <TaskAltRounded />;
  return <CheckCircleRounded />;
}

const formatDate = (value: string) =>
  new Intl.DateTimeFormat('en-AE', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

function notificationTarget(notification: PortalNotification): string {
  if (
    notification.type === 'VehicleApproved' ||
    notification.type === 'VehicleRejected'
  ) {
    return '/provider/fleet';
  }

  return notification.actionUrl || '/provider/notifications';
}

export default function ProviderNotificationsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [unreadOnly, setUnreadOnly] = useState(false);
  const query = useQuery({
    queryKey: [...notificationQueryKey, unreadOnly ? 'unread' : 'all'],
    queryFn: () => getNotifications({ limit: 50, unreadOnly }),
    refetchInterval: 30_000,
  });
  const refresh = () =>
    queryClient.invalidateQueries({ queryKey: notificationQueryKey });
  const markOne = useMutation({ mutationFn: markNotificationRead, onSuccess: refresh });
  const markAll = useMutation({ mutationFn: markAllNotificationsRead, onSuccess: refresh });

  const openNotification = async (notification: PortalNotification) => {
    if (!notification.isRead) await markOne.mutateAsync(notification._id);
    navigate(notificationTarget(notification));
  };

  const notifications = query.data?.notifications ?? [];
  const unreadCount = query.data?.unreadCount ?? 0;

  return (
    <main className="provider-notifications-page">
      <header className="provider-notifications-page__heading">
        <div>
          <span className="provider-notifications-page__eyebrow">Provider inbox</span>
          <h1>Notifications</h1>
          <p>Booking activity and important account updates appear here.</p>
        </div>
        {unreadCount > 0 && (
          <button type="button" onClick={() => markAll.mutate()} disabled={markAll.isPending}>
            Mark all as read
          </button>
        )}
      </header>

      <section className="provider-notifications-page__card">
        <div className="provider-notifications-page__filters" role="tablist" aria-label="Notification filters">
          <button type="button" role="tab" aria-selected={!unreadOnly} className={!unreadOnly ? 'active' : ''} onClick={() => setUnreadOnly(false)}>
            All
          </button>
          <button type="button" role="tab" aria-selected={unreadOnly} className={unreadOnly ? 'active' : ''} onClick={() => setUnreadOnly(true)}>
            Unread <span>{unreadCount}</span>
          </button>
        </div>

        {query.isLoading && <p className="provider-notifications-page__empty">Loading notifications…</p>}
        {query.isError && <p className="provider-notifications-page__empty provider-notifications-page__empty--error">Could not load notifications. Please try again.</p>}
        {!query.isLoading && !query.isError && notifications.length === 0 && (
          <div className="provider-notifications-page__empty">
            <NotificationsNoneRounded />
            <strong>{unreadOnly ? 'No unread notifications' : 'No notifications yet'}</strong>
            <span>New booking and account updates will appear here.</span>
          </div>
        )}

        <div className="provider-notifications-page__list">
          {notifications.map((notification) => (
            <button
              type="button"
              key={notification._id}
              className={`provider-notifications-page__item${notification.isRead ? '' : ' unread'}`}
              onClick={() => void openNotification(notification)}
            >
              <span className={`provider-notifications-page__icon ${notification.type.toLowerCase()}`}>
                {iconFor(notification.type)}
              </span>
              <span className="provider-notifications-page__copy">
                <strong>{notification.title}</strong>
                <span>{notification.message}</span>
                <time dateTime={notification.createdAt}>{formatDate(notification.createdAt)}</time>
              </span>
              {!notification.isRead && <span className="provider-notifications-page__unread">New</span>}
            </button>
          ))}
        </div>
      </section>
    </main>
  );
}
