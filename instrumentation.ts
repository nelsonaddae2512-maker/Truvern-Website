export async function register() {
  // Only initialize if a DSN is present; keeps local/dev clean.
  if (!process.env.SENTRY_DSN) return;
  await import("./sentry.server.config");
  await import("./sentry.client.config");
}