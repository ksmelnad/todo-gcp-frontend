import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  async rewrites() {
    const supabaseUrl = process.env.SUPABASE_URL
    if (!supabaseUrl) return []
    return [
      {
        source: '/api/supabase/:path*',
        destination: `${supabaseUrl}/:path*`,
      },
    ]
  },
}

export default nextConfig
