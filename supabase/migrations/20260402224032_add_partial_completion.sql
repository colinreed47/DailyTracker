alter table public.task_items
  add column if not exists is_partial boolean not null default false;

alter table public.day_records
  add column if not exists partially_completed_task_titles text[] not null default '{}';
