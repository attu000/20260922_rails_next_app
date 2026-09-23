import type { NextConfig } from "next";

// Rails の住所。Docker の中では code/docker-compose.yml の RAILS_API_URL（http://backend:3001）を使う。
// Docker を使わずに手元で動かすときは、localhost の 3001番につなぐ
const railsApiUrl = process.env.RAILS_API_URL ?? "http://localhost:3001";

const nextConfig: NextConfig = {
  // ブラウザからの /api/… と、アイコン画像の /rails/active_storage/… を Rails へ転送する。
  // ブラウザから見ると同じ住所（localhost:3000）になるので、CORS の設定が要らない。
  // 詳しくは design/designs/技術構成.md の 3-1 A-2、API設計.md の 16-1-2
  async rewrites() {
    return [
      {
        source: "/api/:path*",
        destination: `${railsApiUrl}/api/:path*`,
      },
      {
        source: "/rails/active_storage/:path*",
        destination: `${railsApiUrl}/rails/active_storage/:path*`,
      },
    ];
  },
};

export default nextConfig;
