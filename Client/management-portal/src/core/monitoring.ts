import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN || undefined,
  enabled: Boolean(import.meta.env.VITE_SENTRY_DSN) && import.meta.env.VITE_SENTRY_ENABLED === 'true',
  environment: import.meta.env.MODE,
  release: import.meta.env.VITE_SENTRY_RELEASE || undefined,
  sendDefaultPii: false,
  maxBreadcrumbs: 0,
  defaultIntegrations: false,
  integrations: [
    Sentry.globalHandlersIntegration(),
    Sentry.browserApiErrorsIntegration(),
    Sentry.dedupeIntegration(),
  ],
  beforeSend(event, hint) {
    const original = hint.originalException;
    const message = original instanceof Error ? original.message : '';
    // Known browser-extension messaging failure, unrelated to bookings.
    if (message.includes('A listener indicated an asynchronous response') ||
        message.includes('The message port closed before a response was received')) return null;
    // Expected HTTP errors are handled by the UI, not crash reports.
    const status = (original as { response?: { status?: number } } | undefined)?.response?.status;
    if (status && status >= 400 && status < 500) return null;
    return {
      type: event.type,
      event_id: event.event_id,
      timestamp: event.timestamp,
      platform: event.platform,
      level: event.level,
      environment: event.environment,
      release: event.release,
      exception: {
        values: event.exception?.values?.map((exception) => ({
          type: ['Error', 'TypeError', 'ReferenceError', 'SyntaxError', 'RangeError'].includes(exception.type || '')
            ? exception.type : 'Error',
          value: 'Portal failure — inspect stack and operation tags',
          stacktrace: {
            frames: exception.stacktrace?.frames?.map((frame) => ({
              filename: frame.filename?.split(/[?#]/)[0],
              function: frame.function,
              lineno: frame.lineno,
              colno: frame.colno,
              in_app: frame.in_app,
            })),
          },
        })),
      },
      tags: Object.fromEntries(Object.entries(event.tags || {})
        .filter(([key]) => ['operation', 'http_status'].includes(key))),
    };
  },
});

export { Sentry };

export function reportApiFailure(status: number | undefined) {
  if (!status || status < 500) return;
  // Never pass AxiosError: it carries authorization, body and response data.
  Sentry.captureException(new Error('API server failure'), {
    tags: { operation: 'api-request', http_status: status },
  });
}
