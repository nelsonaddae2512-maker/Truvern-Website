/**
 * Minimal instrumentation client shim so Sentry initializes early on the client.
 * (Sentry config already lives in sentry.client.config.ts)
 */
export default function register() {
  // no-op: Next.js will import this file if present
}