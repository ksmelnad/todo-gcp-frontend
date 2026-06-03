'use client'

import { useState, useCallback } from 'react'
import {
  DndContext,
  DragEndEvent,
  DragOverlay,
  DragStartEvent,
  PointerSensor,
  useSensor,
  useSensors,
  closestCenter,
} from '@dnd-kit/core'
import { createClient } from '@/lib/supabase/client'
import { Quadrant } from './quadrant'
import { TodoCard } from './todo-card'
import { type Todo, type Quadrant as QuadrantType } from '@/lib/types'

const QUADRANTS: QuadrantType[] = [
  'urgent_important',
  'urgent_not_important',
  'not_urgent_important',
  'not_urgent_not_important',
]

interface EisenhowerBoardProps {
  initialTodos: Todo[]
}

export function EisenhowerBoard({ initialTodos }: EisenhowerBoardProps) {
  const supabase = createClient()
  const [todos, setTodos] = useState<Todo[]>(initialTodos)
  const [activeId, setActiveId] = useState<string | null>(null)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } })
  )

  const activeTodo = todos.find((t) => t.id === activeId)
  const todosFor = (q: QuadrantType) => todos.filter((t) => t.quadrant === q)

  const handleAdd = useCallback(
    async (title: string, quadrant: QuadrantType) => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data, error } = await supabase
        .from('todos')
        .insert({ title, quadrant, user_id: user.id })
        .select()
        .single()
      if (!error && data) {
        setTodos((prev) => [...prev, data as Todo])
      }
    },
    [supabase]
  )

  const handleComplete = useCallback(
    async (id: string, completed: boolean) => {
      setTodos((prev) =>
        prev.map((t) => (t.id === id ? { ...t, completed } : t))
      )
      await supabase.from('todos').update({ completed }).eq('id', id)
    },
    [supabase]
  )

  const handleDelete = useCallback(
    async (id: string) => {
      setTodos((prev) => prev.filter((t) => t.id !== id))
      await supabase.from('todos').delete().eq('id', id)
    },
    [supabase]
  )

  const handleMove = useCallback(
    async (id: string, quadrant: QuadrantType) => {
      setTodos((prev) =>
        prev.map((t) => (t.id === id ? { ...t, quadrant } : t))
      )
      await supabase.from('todos').update({ quadrant }).eq('id', id)
    },
    [supabase]
  )

  function handleDragStart(event: DragStartEvent) {
    setActiveId(event.active.id as string)
  }

  function handleDragEnd(event: DragEndEvent) {
    setActiveId(null)
    const { active, over } = event
    if (!over) return

    const activeId = active.id as string
    const overId = over.id as string

    const activeTodo = todos.find((t) => t.id === activeId)
    if (!activeTodo) return

    if (QUADRANTS.includes(overId as QuadrantType)) {
      const targetQuadrant = overId as QuadrantType
      if (activeTodo.quadrant !== targetQuadrant) {
        handleMove(activeId, targetQuadrant)
      }
      return
    }

    const overTodo = todos.find((t) => t.id === overId)
    if (!overTodo) return

    if (activeTodo.quadrant !== overTodo.quadrant) {
      handleMove(activeId, overTodo.quadrant)
    }
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCenter}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="grid grid-cols-2 gap-4 h-full">
        {QUADRANTS.map((q) => (
          <Quadrant
            key={q}
            quadrant={q}
            todos={todosFor(q)}
            onAdd={handleAdd}
            onComplete={handleComplete}
            onDelete={handleDelete}
            onMove={handleMove}
          />
        ))}
      </div>

      <DragOverlay>
        {activeTodo ? (
          <TodoCard
            todo={activeTodo}
            onComplete={() => {}}
            onDelete={() => {}}
            onMove={() => {}}
          />
        ) : null}
      </DragOverlay>
    </DndContext>
  )
}
