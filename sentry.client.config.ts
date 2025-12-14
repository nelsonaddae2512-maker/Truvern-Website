// sentry.client.config.ts
import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  tracesSampleRate: 1.0,
  integrations: (integrations) =>
    integrations.filter((integration) => integration.name !== "Console"),
  debug: false,
});
