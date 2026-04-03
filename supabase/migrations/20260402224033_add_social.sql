-- profiles table
create table public.profiles (
  user_id            uuid    not null references auth.users(id) on delete cascade,
  display_name       text    not null default 'Friend',
  friend_code        text    not null unique default upper(substring(md5(gen_random_uuid()::text), 1, 6)),
  is_sharing_enabled boolean not null default true,
  constraint profiles_pkey primary key (user_id)
);

alter table public.profiles enable row level security;

create policy "Users can read own profile"
  on public.profiles for select using (auth.uid() = user_id);
create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = user_id);
create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Friends can read each other's profiles (accepted friendships or incoming pending requests)
create policy "Friends can read profiles"
  on public.profiles for select
  using (
    exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = profiles.user_id)
          or
          (f.addressee_id = auth.uid() and f.requester_id = profiles.user_id)
        )
    )
    or exists (
      select 1 from public.friendships f
      where f.addressee_id = auth.uid()
        and f.requester_id = profiles.user_id
        and f.status = 'pending'
    )
  );

-- friendships table
create table public.friendships (
  id           uuid        not null default gen_random_uuid(),
  requester_id uuid        not null references auth.users(id) on delete cascade,
  addressee_id uuid        not null references auth.users(id) on delete cascade,
  status       text        not null default 'pending' check (status in ('pending', 'accepted')),
  created_at   timestamptz not null default now(),
  constraint friendships_pkey primary key (id),
  constraint friendships_unique unique (requester_id, addressee_id)
);

create index friendships_requester_idx on public.friendships (requester_id);
create index friendships_addressee_idx on public.friendships (addressee_id);

alter table public.friendships enable row level security;

create policy "Users can read own friendships"
  on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "Users can insert friendships as requester"
  on public.friendships for insert
  with check (auth.uid() = requester_id);
create policy "Addressee can accept friendships"
  on public.friendships for update
  using (auth.uid() = addressee_id)
  with check (auth.uid() = addressee_id);

-- Allow friends to read day_records if sharing is enabled
create policy "Friends can read shared day records"
  on public.day_records for select
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = day_records.user_id
        and p.is_sharing_enabled = true
    )
    and exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester_id = auth.uid() and f.addressee_id = day_records.user_id)
          or
          (f.addressee_id = auth.uid() and f.requester_id = day_records.user_id)
        )
    )
  );

-- View that exposes only completion counts (no task titles) for friend calendars
create or replace view public.friend_calendar_view
with (security_invoker = true)
as
select
  dr.user_id,
  dr.date_string,
  cardinality(dr.all_task_titles)                    as total_count,
  cardinality(dr.completed_task_titles)              as completed_count,
  cardinality(dr.partially_completed_task_titles)    as partial_count
from public.day_records dr;

-- RPC: look up a user by friend code and create a pending friendship
-- Uses security definer so the caller can search profiles without needing RLS access to all rows
create or replace function public.add_friend_by_code(p_friend_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_addressee_id uuid;
begin
  select user_id into v_addressee_id
  from public.profiles
  where friend_code = upper(trim(p_friend_code));

  if v_addressee_id is null then
    return jsonb_build_object('error', 'code_not_found');
  end if;

  if v_addressee_id = auth.uid() then
    return jsonb_build_object('error', 'self');
  end if;

  if exists (
    select 1 from public.friendships
    where (requester_id = auth.uid() and addressee_id = v_addressee_id)
       or (requester_id = v_addressee_id and addressee_id = auth.uid())
  ) then
    return jsonb_build_object('error', 'already_exists');
  end if;

  insert into public.friendships (requester_id, addressee_id, status)
  values (auth.uid(), v_addressee_id, 'pending');

  return jsonb_build_object('success', true);
end;
$$;

-- RPC: returns all friendships (pending + accepted) with the other person's profile data
create or replace function public.get_my_friends()
returns table (
  friendship_id      uuid,
  status             text,
  is_requester       boolean,
  user_id            uuid,
  display_name       text,
  friend_code        text,
  is_sharing_enabled boolean
)
language sql
security definer
set search_path = public
as $$
  select
    f.id                              as friendship_id,
    f.status,
    (f.requester_id = auth.uid())     as is_requester,
    p.user_id,
    p.display_name,
    p.friend_code,
    p.is_sharing_enabled
  from public.friendships f
  join public.profiles p
    on p.user_id = case
      when f.requester_id = auth.uid() then f.addressee_id
      else f.requester_id
    end
  where f.requester_id = auth.uid()
     or f.addressee_id = auth.uid()
  order by f.created_at desc;
$$;
