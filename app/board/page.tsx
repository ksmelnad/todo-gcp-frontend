import { createClient } from '@/lib/supabase/server'
import { EisenhowerBoard } from '@/components/board/eisenhower-board'
import type { Todo } from '@/lib/types'

export default async function BoardPage() {
  const supabase = await createClient()
  const { data: todos, error } = await supabase
    .from('todos')
    .select('*')
    .order('created_at', { ascending: true })

  if (error) {
    console.error('Error fetching todos:', error)
  }

  return <EisenhowerBoard initialTodos={(todos as Todo[]) ?? []} />
}
