import type { NextConfig } from "next";

const nextConfig = {
  async redirects() {
    return [
      {
        source: '/about',
        destination: 'https://api.farcaster.xyz/miniapps/hosted-manifest/01998eaf-3909-9238-da15-b05e1e75cab3',
        permanent: true,
      },
    ]
  },
};

export default nextConfig;
