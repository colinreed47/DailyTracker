-- Reassigns all DailyTracker data from one user to another.
-- Fallback recovery path (Path B in docs/ACCOUNT_RECOVERY.md): use when the
-- old account itself is not being recovered and its data should move to the
-- account currently on the device.
--
-- Run in the Supabase SQL editor. Replace the two UUIDs below first.
-- See docs/ACCOUNT_RECOVERY.md Step 0 for how to identify them.

do $$
declare
  old_user uuid := '00000000-0000-0000-0000-000000000000';  -- account that owns the data
  new_user uuid := '11111111-1111-1111-1111-111111111111';  -- account on the device now
begin
  if not exists (select 1 from auth.users where id = old_user) then
    raise exception 'old_user % not found in auth.users', old_user;
  end if;
  if not exists (select 1 from auth.users where id = new_user) then
    raise exception 'new_user % not found in auth.users', new_user;
  end if;

  update public.task_items set user_id = new_user where user_id = old_user;

  -- The new account may have created day records since the incident (unique
  -- on user_id + date_string). Keep the old account's richer record for any
  -- clashing date by removing the new account's copy first.
  delete from public.day_records
  where user_id = new_user
    and date_string in (
      select date_string from public.day_records where user_id = old_user
    );
  update public.day_records set user_id = new_user where user_id = old_user;

  -- profiles is keyed by user_id; keep the old profile (name, friend code).
  delete from public.profiles where user_id = new_user;
  update public.profiles set user_id = new_user where user_id = old_user;

  -- Move friendships, skipping any that would collide with ones the new
  -- account already has.
  update public.friendships f set requester_id = new_user
  where f.requester_id = old_user
    and not exists (
      select 1 from public.friendships x
      where x.requester_id = new_user and x.addressee_id = f.addressee_id
    );
  update public.friendships f set addressee_id = new_user
  where f.addressee_id = old_user
    and not exists (
      select 1 from public.friendships x
      where x.requester_id = f.requester_id and x.addressee_id = new_user
    );
  -- Remove any leftovers that collided.
  delete from public.friendships where requester_id = old_user or addressee_id = old_user;
end $$;
