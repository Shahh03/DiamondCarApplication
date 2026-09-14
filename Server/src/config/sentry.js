import * as Sentry from "@sentry/node";
import dotenv from "dotenv";
import { fileURLToPath } from "node:url";

dotenv.config({ path: fileURLToPath(new URL("../../.env", import.meta.url)) });
const enabled = Boolean(process.env.SENTRY_DSN) && process.env.SENTRY_ENABLED === "true";

Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  enabled,
  environment: process.env.NODE_ENV || "development",
  release: process.env.SENTRY_RELEASE || undefined,
  sendDefaultPii: false,
  maxBreadcrumbs: 0,
  // Error-only setup: no database/HTTP instrumentation, tracing, logs or replay.
  defaultIntegrations: false,
  integrations: [
    Sentry.onUncaughtExceptionIntegration(),
    Sentry.onUnhandledRejectionIntegration({ mode: "strict" }),
  ],
  beforeSend(event) {
    // Allowlist rather than trying to guess every possible secret field.
    const safe = {
      type: event.type,
      event_id: event.event_id,
      timestamp: event.timestamp,
      platform: event.platform,
      level: event.level,
      environment: event.environment,
      release: event.release,
      exception: {
        values: event.exception?.values?.map((exception) => ({
          type: ["Error", "TypeError", "ReferenceError", "SyntaxError", "RangeError"].includes(exception.type)
            ? exception.type : "Error",
          value: "Backend failure — inspect stack and operation tags",
          stacktrace: {
            frames: exception.stacktrace?.frames?.map((frame) => ({
              // Keep code locations, omit source snippets and local variables.
              filename: frame.filename?.replace(/^.*?[\\/]Server[\\/]/, "Server/").split("?")[0],
              function: frame.function,
              lineno: frame.lineno,
              colno: frame.colno,
              in_app: frame.in_app,
            })),
          },
        })),
      },
      tags: Object.fromEntries(
        Object.entries(event.tags || {}).filter(([key]) => ["operation", "http_status", "route"].includes(key))
      ),
    };
    return safe;
  },
});

export { Sentry };

export function captureServerFailure(error, operation = "server") {
  return Sentry.captureException(error, { tags: { operation } });
}

// This captures controllers which catch their own error and return a 500.
// Their original stack is unavailable here; use captureServerFailure inside
// that controller's catch when investigating a particular failure.
export function monitorServerResponses(req, res, next) {
  res.on("finish", () => {
    if (res.statusCode < 500 || res.locals.sentryReported) return;
    // Express route templates contain parameter names, not customer IDs.
    const route = typeof req.route?.path === "string" ? req.route.path : "unmatched";
    Sentry.captureException(new Error("HTTP server failure"), {
      tags: { operation: "http-response", http_status: res.statusCode, route },
    });
  });
  next();
}
