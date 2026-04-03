create table public.task_items (
  id           uuid        not null default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  title        text        not null,
  is_completed boolean     not null default false,
  order_index  integer     not null default 0,
  created_at   timestamptz not null default now(),
  constraint task_items_pkey primary key (id)
);

create index task_items_user_order_idx on public.task_items (user_id, order_index);

alter table public.task_items enable row level security;

create policy "Users can select their own task items"
  on public.task_items for select using (auth.uid() = user_id);
create policy "Users can insert their own task items"
  on public.task_items for insert with check (auth.uid() = user_id);
create policy "Users can update their own task items"
  on public.task_items for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete their own task items"
  on public.task_items for delete using (auth.uid() = user_id);
