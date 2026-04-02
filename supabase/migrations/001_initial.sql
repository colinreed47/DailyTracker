-- task_items: the user's repeating daily tasks
create table public.task_items (
    id           uuid        primary key,
    user_id      uuid        not null references auth.users(id) on delete cascade,
    title        text        not null,
    is_completed boolean     not null default false,
    order_index  integer     not null default 0,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

-- day_records: one snapshot per user per calendar day
create table public.day_records (
    id                    uuid        primary key,
    user_id               uuid        not null references auth.users(id) on delete cascade,
    date_string           text        not null,
    all_task_titles       text[]      not null default '{}',
    completed_task_titles text[]      not null default '{}',
    updated_at            timestamptz not null default now(),
    unique (user_id, date_string)
);

create index on public.task_items  (user_id, order_index);
create index on public.day_records (user_id, date_string);

-- auto-update updated_at on every row change
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger task_items_updated_at
  before update on public.task_items
  for each row execute procedure public.set_updated_at();

create trigger day_records_updated_at
  before update on public.day_records
  for each row execute procedure public.set_updated_at();
