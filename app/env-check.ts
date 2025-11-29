/**
 * Minimal runtime env validation.
 * Throws in production if critical env vars are missing.
 */
const required = [
  'NEXT_PUBLIC_APP_URL',
  'DATABASE_URL',
];

const missing = required.filter((k) => !process.env[k] || String(process.env[k]).trim() === '');
if (missing.length > 0) {
  const msg = `Missing required env vars: ${missing.join(', ')}`;
  if (process.env.NODE_ENV === 'production') {
    throw new Error(msg);
  } else {
    console.warn('[env-check]', msg);
  }
}