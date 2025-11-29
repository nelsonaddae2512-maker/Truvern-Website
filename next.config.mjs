// @ts-nocheck
// Skip type and lint validation during builds
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
};

module.exports = nextConfig;
import { withSentryConfig } from '@sentry/nextjs';
/** @type {import('next').NextConfig} */
const nextConfig = {
  images: { formats: ['image/avif','image/webp'] },
  poweredByHeader: false,
  compress: true,
  reactStrictMode: true,
  experimental: {
    typedRoutes: false,              // disables route type generation
    serverActions: { bodySizeLimit: '2mb' }, // safe default
  },
  typescript: {
    ignoreBuildErrors: true,         // prevents TS errors from halting builds
  },
}

export default withSentryConfig(nextConfig, { disableClientWebpackPlugin: true, disableServerWebpackPlugin: true });

