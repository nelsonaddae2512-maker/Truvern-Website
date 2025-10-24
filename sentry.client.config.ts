import * as Sentry from "@sentry/nextjs";
Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  tracesSampleRate: 0.2,
  replaysOnErrorSampleRate: 0.1,
  integrations: [],
});