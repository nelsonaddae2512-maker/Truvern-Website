import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN || process.env.SENTRY_DSN,
  tracesSampleRate: 0, // keep 0 locally; raise in prod if you want
  enabled: process.env.NODE_ENV === "production",
});
