import * as Sentry from '@sentry/nextjs';

/**
 * Centralized logging helper for Truvern.
 * Logs to console and sends high-level messages to Sentry.
 */
export function log(...args: any[]) {
  if (process.env.NODE_ENV !== "production") {
    console.log("[TRUVERN LOG]", ...args);
  }
}
export function logMessage(
  message: string,
  level: 'debug' | 'info' | 'warn' | 'error' = 'info',
  extra?: Record<string, any>
) {
  try {
    // Send only warnings or errors to Sentry
    if (level === 'error' || level === 'warn') {
      Sentry.captureMessage(message, { level, extra });
    }

    // ✅ Correct formatting (no backslashes)
    const time = new Date().toISOString();
    const line = `[${level.toUpperCase()}] ${time} :: ${message}`;

    if (level === 'debug') console.debug(line, extra ?? {});
    else if (level === 'info') console.info(line, extra ?? {});
    else if (level === 'warn') console.warn(line, extra ?? {});
    else console.error(line, extra ?? {});
  } catch (err) {
    console.error('Logger error:', err);
  }
}
