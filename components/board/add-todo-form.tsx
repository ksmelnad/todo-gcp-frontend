'use client'

import { useState } from 'react'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Plus } from 'lucide-react'
import type { Quadrant } from '@/lib/types'

interface AddTodoFormProps {
  quadrant: Quadrant
  onAdd: (title: string, quadrant: Quadrant) => void
}

export function AddTodoForm({ quadrant, onAdd }: AddTodoFormProps) {
  const [title, setTitle] = useState('')
  const [open, setOpen] = useState(false)

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    const trimmed = title.trim()
    if (!trimmed) return
    onAdd(trimmed, quadrant)
    setTitle('')
    setOpen(false)
  }

  if (!open) {
    return (
      <Button
        variant="ghost"
        size="sm"
        className="w-full justify-start text-slate-400 hover:text-slate-600 hover:bg-transparent"
        onClick={() => setOpen(true)}
      >
        <Plus size={14} className="mr-1" />
        Add task
      </Button>
    )
  }

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <Input
        autoFocus
        placeholder="Task title…"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        onKeyDown={(e) => e.key === 'Escape' && setOpen(false)}
        className="h-8 text-sm"
      />
      <Button type="submit" size="sm" className="h-8">
        Add
      </Button>
    </form>
  )
}
