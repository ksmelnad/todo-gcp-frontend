import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { Button } from '@/components/ui/button'

async function signOut() {
  'use server'
  const supabase = await createClient()
  await supabase.auth.signOut()
  redirect('/login')
}

export default async function BoardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect('/login')
  }

  return (
    <div className="min-h-screen bg-slate-100">
      <header className="bg-white border-b px-6 py-3 flex items-center justify-between">
        <h1 className="text-lg font-semibold">Eisenhower Matrix</h1>
        <div className="flex items-center gap-4">
          <span className="text-sm text-slate-500">{user.email}</span>
          <form action={signOut}>
            <Button variant="outline" size="sm" type="submit">
              Sign Out
            </Button>
          </form>
        </div>
      </header>
      <main className="p-6">{children}</main>
    </div>
  )
}
