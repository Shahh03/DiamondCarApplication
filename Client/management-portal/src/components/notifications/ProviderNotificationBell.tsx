import {
  CalendarMonthRounded,
  CheckCircleRounded,
  DirectionsCarRounded,
  NotificationsNoneRounded,
  TaskAltRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import {
  getNotifications,
  markAllNotificationsRead,
  markNotificationRead,
  type PortalNotification,
} from '../../api/notifications/notificationApi';

import './ProviderNotificationBell.css';

export const notificationQueryKey = ['provider-notifications'] as const;

const relativeTime = (value: string) => {
  const seconds = Math.round((new Date(value).getTime() - Date.now()) / 1000);
  const formatter = new Intl.RelativeTimeFormat('en', { numeric: 'auto' });
  if (Math.abs(seconds) < 60) return formatter.format(seconds, 'second');
  const minutes = Math.round(seconds / 60);
  if (Math.abs(minutes) < 60) return formatter.format(minutes, 'minute');
  const hours = Math.round(minutes / 60);
  if (Math.abs(hours) < 24) return formatter.format(hours, 'hour');
  return formatter.format(Math.round(hours / 24), 'day');
};

function NotificationIcon({ type }: { type: PortalNotification['type'] }) {
  if (type === 'BookingConfirmed' || type === 'BookingCancelled') {
    return <CalendarMonthRounded />;
  }
  if (type === 'VehicleApproved' || type === 'VehicleRejected') {
    return <DirectionsCarRounded />;
  }
  if (type === 'ProviderApproved') return <TaskAltRounded />;
  return <CheckCircleRounded />;
}

function notificationTarget(notification: PortalNotification): string {
  if (
    notification.type === 'VehicleApproved' ||
    notification.type === 'VehicleRejected'
  ) {
    return '/provider/fleet';
  }

  return notification.actionUrl || '/provider/notifications';
}

export default function ProviderNotificationBell() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const rootRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const query = useQuery({
    queryKey: notificationQueryKey,
    queryFn: () => getNotifications({ limit: 6 }),
    refetchInterval: 30_000,
    staleTime: 10_000,
  });

  const refresh = () =>
    queryClient.invalidateQueries({ queryKey: notificationQueryKey });
  const markOne = useMutation({ mutationFn: markNotificationRead, onSuccess: refresh });
  const markAll = useMutation({ mutationFn: markAllNotificationsRead, onSuccess: refresh });

  useEffect(() => {
    if (!open) return undefined;
    const handlePointer = (event: MouseEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const handleKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', handlePointer);
    document.addEventListener('keydown', handleKey);
    return () => {
      document.removeEventListener('mousedown', handlePointer);
      document.removeEventListener('keydown', handleKey);
    };
  }, [open]);

  const openNotification = async (notification: PortalNotification) => {
    if (!notification.isRead) await markOne.mutateAsync(notification._id);
    setOpen(false);
    navigate(notificationTarget(notification));
  };

  const unreadCount = query.data?.unreadCount ?? 0;
  const notifications = query.data?.notifications ?? [];

  return (
    <div className="provider-notification" ref={rootRef}>
      <button
        className="provider-layout__notification-button"
        type="button"
        aria-label={unreadCount ? `${unreadCount} unread notifications` : 'Notifications'}
        aria-expanded={open}
        aria-haspopup="dialog"
        onClick={() => setOpen((value) => !value)}
      >
        <NotificationsNoneRounded />
        {unreadCount > 0 && (
          <span className="provider-notification__badge">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>

      {open && (
        <section className="provider-notification__panel" role="dialog" aria-label="Notifications">
          <header className="provider-notification__header">
            <div><strong>Notifications</strong><span>{unreadCount} unread</span></div>
            {unreadCount > 0 && (
              <button type="button" onClick={() => markAll.mutate()} disabled={markAll.isPending}>
                Mark all read
              </button>
            )}
          </header>

          <div className="provider-notification__list">
            {query.isLoading && <p className="provider-notification__state">Loading notifications…</p>}
            {query.isError && <p className="provider-notification__state provider-notification__state--error">Could not load notifications.</p>}
            {!query.isLoading && !query.isError && notifications.length === 0 && (
              <p className="provider-notification__state">You have no notifications yet.</p>
            )}
            {notifications.map((notification) => (
              <button
                key={notification._id}
                type="button"
                className={`provider-notification__item${notification.isRead ? '' : ' provider-notification__item--unread'}`}
                onClick={() => void openNotification(notification)}
              >
                <span className={`provider-notification__icon provider-notification__icon--${notification.type.toLowerCase()}`}>
                  <NotificationIcon type={notification.type} />
                </span>
                <span className="provider-notification__copy">
                  <strong>{notification.title}</strong>
                  <span>{notification.message}</span>
                  <time dateTime={notification.createdAt}>{relativeTime(notification.createdAt)}</time>
                </span>
                {!notification.isRead && <span className="provider-notification__dot" aria-label="Unread" />}
              </button>
            ))}
          </div>

          <button
            className="provider-notification__all"
            type="button"
            onClick={() => { setOpen(false); navigate('/provider/notifications'); }}
          >
            View all notifications
          </button>
        </section>
      )}
    </div>
  );
}
