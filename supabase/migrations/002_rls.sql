alter table public.task_items  enable row level security;
alter table public.day_records enable row level security;

create policy "Users manage own tasks"
  on public.task_items for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users manage own day records"
  on public.day_records for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);
