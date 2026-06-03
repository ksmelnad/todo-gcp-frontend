'use client'
import type { Todo } from '@/lib/types'

export function EisenhowerBoard({ initialTodos }: { initialTodos: Todo[] }) {
  return <div>Board placeholder ({initialTodos.length} todos)</div>
}
