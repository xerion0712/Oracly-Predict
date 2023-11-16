/** @type {import('next').NextConfig} */
const nextConfig = {
  env: {
    COINMARKETCAP_API: process.env.COINMARKETCAP_API
  },
  eslint: {
    ignoreDuringBuilds: true,
  },
  reactStrictMode: true,
}

module.exports = nextConfig
