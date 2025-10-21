/**
 * Mock i18n client hook for builds.
 * Fixes "Cannot find module '@/lib/i18n/client'" errors.
 * Safe placeholder until real translations are added.
 */

export function useI18n() {
  return {
    t: (key: string) => key,        // returns key as translation
    locale: "en",                   // default locale
    setLocale: (_: string) => {},   // no-op setter
  };
}
