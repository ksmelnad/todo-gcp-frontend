'use server'

import { createClient } from '@/lib/supabase/server'
import { type Quadrant } from '@/lib/types'

export async function addTodo(title: string, quadrant: Quadrant) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Not authenticated')
  const { data, error } = await supabase
    .from('todos')
    .insert({ title, quadrant, user_id: user.id })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function completeTodo(id: string, completed: boolean) {
  const supabase = await createClient()
  const { error } = await supabase.from('todos').update({ completed }).eq('id', id)
  if (error) throw error
}

export async function moveTodo(id: string, quadrant: Quadrant) {
  const supabase = await createClient()
  const { error } = await supabase.from('todos').update({ quadrant }).eq('id', id)
  if (error) throw error
}

export async function removeTodo(id: string) {
  const supabase = await createClient()
  const { error } = await supabase.from('todos').delete().eq('id', id)
  if (error) throw error
}
