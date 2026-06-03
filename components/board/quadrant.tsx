'use client'

import { useDroppable } from '@dnd-kit/core'
import { SortableContext, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { Badge } from '@/components/ui/badge'
import { TodoCard } from './todo-card'
import { AddTodoForm } from './add-todo-form'
import { QUADRANT_LABELS, type Todo, type Quadrant as QuadrantType } from '@/lib/types'

interface QuadrantProps {
  quadrant: QuadrantType
  todos: Todo[]
  onAdd: (title: string, quadrant: QuadrantType) => void
  onComplete: (id: string, completed: boolean) => void
  onDelete: (id: string) => void
  onMove: (id: string, quadrant: QuadrantType) => void
}

export function Quadrant({
  quadrant,
  todos,
  onAdd,
  onComplete,
  onDelete,
  onMove,
}: QuadrantProps) {
  const { setNodeRef, isOver } = useDroppable({ id: quadrant })
  const label = QUADRANT_LABELS[quadrant]

  return (
    <div
      ref={setNodeRef}
      className={`flex flex-col h-full min-h-64 rounded-xl border-2 p-4 transition-colors ${
        label.color
      } ${isOver ? 'ring-2 ring-offset-1 ring-blue-400' : ''}`}
    >
      <div className="mb-3">
        <div className="flex items-center justify-between">
          <h2 className="font-semibold text-slate-800">{label.title}</h2>
          <Badge variant="secondary" className="text-xs">
            {todos.length}
          </Badge>
        </div>
        <p className="text-xs text-slate-500 mt-0.5">{label.subtitle}</p>
      </div>

      <SortableContext
        items={todos.map((t) => t.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="flex flex-col gap-2 flex-1">
          {todos.map((todo) => (
            <TodoCard
              key={todo.id}
              todo={todo}
              onComplete={onComplete}
              onDelete={onDelete}
              onMove={onMove}
            />
          ))}
        </div>
      </SortableContext>

      <div className="mt-3">
        <AddTodoForm quadrant={quadrant} onAdd={onAdd} />
      </div>
    </div>
  )
}
