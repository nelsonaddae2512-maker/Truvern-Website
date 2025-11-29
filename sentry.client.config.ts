import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV,
  tracesSampleRate: 0.2,              // perf tracing (20%)
  replaysSessionSampleRate: 0.05,     // session replays (5%)
  replaysOnErrorSampleRate: 1.0,      // always replay on error
});