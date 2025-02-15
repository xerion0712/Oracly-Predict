/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    FIRECRAWL_API_KEY: process.env.FIRECRAWL_API_KEY,
    ATOMA_API_KEY: process.env.ATOMA_API_KEY
  },
  swcMinify: true,
  eslint: {
    ignoreDuringBuilds: true,
  },
};

export default nextConfig;
