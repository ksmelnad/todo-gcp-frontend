export type Quadrant =
  | 'urgent_important'
  | 'urgent_not_important'
  | 'not_urgent_important'
  | 'not_urgent_not_important'

export interface Todo {
  id: string
  user_id: string
  title: string
  quadrant: Quadrant
  completed: boolean
  created_at: string
  updated_at: string
}

export const QUADRANT_LABELS: Record<Quadrant, { title: string; subtitle: string; color: string }> = {
  urgent_important: {
    title: 'Do First',
    subtitle: 'Urgent + Important',
    color: 'border-red-500 bg-red-50',
  },
  urgent_not_important: {
    title: 'Delegate',
    subtitle: 'Urgent + Not Important',
    color: 'border-orange-400 bg-orange-50',
  },
  not_urgent_important: {
    title: 'Schedule',
    subtitle: 'Not Urgent + Important',
    color: 'border-blue-500 bg-blue-50',
  },
  not_urgent_not_important: {
    title: 'Eliminate',
    subtitle: 'Not Urgent + Not Important',
    color: 'border-slate-400 bg-slate-50',
  },
}
