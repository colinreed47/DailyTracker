create table public.day_records (
  id                    uuid    not null default gen_random_uuid(),
  user_id               uuid    not null references auth.users(id) on delete cascade,
  date_string           text    not null,
  all_task_titles       text[]  not null default '{}',
  completed_task_titles text[]  not null default '{}',
  constraint day_records_pkey primary key (id),
  constraint day_records_user_date_unique unique (user_id, date_string)
);

create index day_records_user_date_idx on public.day_records (user_id, date_string);

alter table public.day_records enable row level security;

create policy "Users can select their own day records"
  on public.day_records for select using (auth.uid() = user_id);
create policy "Users can insert their own day records"
  on public.day_records for insert with check (auth.uid() = user_id);
create policy "Users can update their own day records"
  on public.day_records for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users can delete their own day records"
  on public.day_records for delete using (auth.uid() = user_id);
