// sentry.server.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  tracesSampleRate: 1.0,
  // Turn off noisy console instrumentation that is causing the sourcemap error
  integrations: (integrations) =>
    integrations.filter((integration) => integration.name !== "Console"),
  debug: false,
});
