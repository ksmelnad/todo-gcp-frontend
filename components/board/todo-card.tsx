'use client'

import { useSortable } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { Card, CardContent } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { GripVertical, Trash2, MoveHorizontal } from 'lucide-react'
import { QUADRANT_LABELS, type Todo, type Quadrant } from '@/lib/types'

interface TodoCardProps {
  todo: Todo
  onComplete: (id: string, completed: boolean) => void
  onDelete: (id: string) => void
  onMove: (id: string, quadrant: Quadrant) => void
}

export function TodoCard({ todo, onComplete, onDelete, onMove }: TodoCardProps) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({ id: todo.id })

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.4 : 1,
  }

  return (
    <Card
      ref={setNodeRef}
      style={style}
      className={`group ${isDragging ? 'shadow-lg' : 'hover:shadow-sm'} transition-shadow`}
    >
      <CardContent className="p-3 flex items-start gap-2">
        <button
          {...attributes}
          {...listeners}
          className="mt-0.5 cursor-grab active:cursor-grabbing text-slate-300 hover:text-slate-500 transition-colors"
          aria-label="Drag to reorder"
        >
          <GripVertical size={16} />
        </button>

        <Checkbox
          id={`todo-${todo.id}`}
          checked={todo.completed}
          onCheckedChange={(checked) => onComplete(todo.id, checked as boolean)}
          className="mt-0.5"
        />

        <span
          className={`flex-1 text-sm leading-snug ${
            todo.completed ? 'line-through text-slate-400' : 'text-slate-700'
          }`}
        >
          {todo.title}
        </span>

        <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="h-6 w-6">
                <MoveHorizontal size={12} />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {(Object.keys(QUADRANT_LABELS) as Quadrant[])
                .filter((q) => q !== todo.quadrant)
                .map((q) => (
                  <DropdownMenuItem key={q} onClick={() => onMove(todo.id, q)}>
                    Move to: {QUADRANT_LABELS[q].title}
                  </DropdownMenuItem>
                ))}
            </DropdownMenuContent>
          </DropdownMenu>

          <Button
            variant="ghost"
            size="icon"
            className="h-6 w-6 text-slate-400 hover:text-red-500"
            onClick={() => onDelete(todo.id)}
          >
            <Trash2 size={12} />
          </Button>
        </div>
      </CardContent>
    </Card>
  )
}
