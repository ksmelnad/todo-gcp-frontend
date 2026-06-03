create table public.todos (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete cascade not null,
  title       text not null,
  quadrant    text not null check (quadrant in (
                'urgent_important',
                'urgent_not_important',
                'not_urgent_important',
                'not_urgent_not_important'
              )),
  completed   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.todos enable row level security;

create policy "users own their todos"
  on public.todos
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index todos_user_id_idx on public.todos(user_id);
create index todos_quadrant_idx on public.todos(user_id, quadrant);
