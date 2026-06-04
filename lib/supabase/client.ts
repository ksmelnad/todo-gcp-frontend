import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  // In the browser, derive the URL from the current origin so this works on
  // any deployment domain without hardcoding. During SSR (window undefined),
  // fall back to the direct VM URL — no API calls happen server-side here.
  const supabaseUrl =
    typeof window !== 'undefined'
      ? `${window.location.origin}/api/supabase`
      : process.env.SUPABASE_URL!

  return createBrowserClient(
    supabaseUrl,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
