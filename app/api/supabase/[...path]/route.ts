import { type NextRequest, NextResponse } from 'next/server'

const SUPABASE_URL = process.env.SUPABASE_URL

const REQUEST_HEADERS = [
  'apikey', 'authorization', 'content-type', 'content-length',
  'accept', 'prefer', 'range', 'x-client-info', 'x-supabase-api-version',
]

const RESPONSE_HEADERS = [
  'content-type', 'content-range', 'x-total-count', 'content-length',
]

async function proxy(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  if (!SUPABASE_URL) {
    return NextResponse.json({ error: 'SUPABASE_URL not configured' }, { status: 503 })
  }

  const { path } = await params
  const target = `${SUPABASE_URL}/${path.join('/')}${req.nextUrl.search}`

  const headers = new Headers()
  for (const key of REQUEST_HEADERS) {
    const val = req.headers.get(key)
    if (val) headers.set(key, val)
  }

  const hasBody = req.method !== 'GET' && req.method !== 'HEAD'
  const fetchOptions: RequestInit & { duplex?: string } = {
    method: req.method,
    headers,
    body: hasBody ? req.body : undefined,
    duplex: hasBody ? 'half' : undefined,
  }

  const upstream = await fetch(target, fetchOptions as RequestInit)

  const resHeaders = new Headers()
  for (const key of RESPONSE_HEADERS) {
    const val = upstream.headers.get(key)
    if (val) resHeaders.set(key, val)
  }

  return new NextResponse(upstream.body, {
    status: upstream.status,
    headers: resHeaders,
  })
}

export const GET = proxy
export const POST = proxy
export const PUT = proxy
export const PATCH = proxy
export const DELETE = proxy
export const OPTIONS = proxy
export const HEAD = proxy
