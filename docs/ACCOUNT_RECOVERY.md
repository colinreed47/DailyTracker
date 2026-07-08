# Recovering an orphaned account

## Background

Before the fix in this branch, a failed session load on launch (e.g. a token
refresh attempted right after a device reboot, before the network was up)
caused the app to create a **new** anonymous Supabase user. The old account —
and every `task_items`, `day_records`, `profiles`, and `friendships` row tied
to it — still exists in the database, but Row Level Security hides it from the
new user, so the app looks empty.

There are two ways back. **Path A recovers the old account itself** (keeps the
same user ID, so friendships keep working in both directions) and is the
recommended one. Path B copies the data to the new account instead.

Both paths need the Supabase **service role key** (Dashboard → Project
Settings → API). Never ship or commit that key.

## Step 0 — Identify the old user ID

Run this in the Supabase SQL editor:

```sql
select
  u.id,
  u.created_at,
  u.last_sign_in_at,
  u.email,
  (select count(*) from public.task_items  t where t.user_id = u.id) as task_count,
  (select count(*) from public.day_records d where d.user_id = u.id) as day_count,
  (select p.display_name from public.profiles p where p.user_id = u.id) as display_name
from auth.users u
order by u.created_at;
```

The **old** account is the one with your task/day counts and display name and
an older `created_at`. The **new** (accidental) account was created the day of
the reboot and has little or no data. The old ID also matches the `userId`
stored on the device's local records.

## Path A (recommended): recover the old account via email

1. **Attach your email to the old user** with the admin API (one-time, run
   from your machine — replace placeholders):

   ```bash
   curl -X PUT "https://bchsgwwlqojfbnrcyqem.supabase.co/auth/v1/admin/users/<OLD_USER_ID>" \
     -H "apikey: <SERVICE_ROLE_KEY>" \
     -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"email": "<your-email>", "email_confirm": true}'
   ```

2. **Make sure sign-in codes appear in emails.** Dashboard → Authentication →
   Email Templates → *Magic Link*: the body must contain `{{ .Token }}`
   (the 6-digit code), e.g.

   ```html
   <p>Your sign-in code is: {{ .Token }}</p>
   ```

3. **In the app** (a build with this branch): if it's a fresh install, the
   welcome screen offers **I already have an account** directly — tap it,
   enter the email, enter the emailed code. If the app is already showing an
   (empty) account, use the Friends screen (person icon) → **Account** →
   **Sign In to Existing Account…** instead. Either way, the app switches to
   the old user ID; local data is rebound automatically and anything missing
   locally is pulled down from the database. Friendships work again
   immediately because the user ID is unchanged.

4. **Optional cleanup:** delete the accidental new user in Dashboard →
   Authentication → Users. Do this only *after* recovery has completed on the
   device — deleting the user cascade-deletes its rows.

Going forward, every user is prompted to pre-empt this entirely: the app now
nudges anonymous users once they've used it for a day to tap **Create
Account** (Friends → Account has the same button), which attaches an email to
the anonymous account and makes it recoverable on any device — from a proper
**I already have an account** option on the welcome screen, not just a rescue
path buried in settings.

## Path B (fallback): reassign the data to the new account

If you'd rather keep the new account, run
`supabase/scripts/reassign_user_data.sql` in the SQL editor after filling in
the old and new user IDs. Note that friends would then see you under a new
user ID, and the old account can be deleted afterwards.

## What the app-side fix changed

- A session-load failure no longer creates a new anonymous account; the app
  falls back to the stored session or the cached user ID, retries on every
  foreground, and only signs in anonymously when the user explicitly taps
  **Get Started** on a device with no known identity at all.
- **First launch now asks.** A brand-new install shows a welcome screen with
  **Get Started** (new anonymous account, same zero-friction start as before)
  or **I already have an account** (sign in by email code) — instead of
  silently assuming "new device = new account", which is what orphaned
  accounts in the first place.
- **A one-time "Save Your Account" nudge** appears after a day of anonymous
  use (and again every few days until acted on) prompting **Create Account**,
  so protecting the account doesn't depend on someone finding it in settings.
- Accounts can be protected with a linked email and recovered with a one-time
  emailed code, from both the welcome screen and Friends → Account.
- The app can now *read* its data back from Supabase (it previously only
  wrote), so a recovered or freshly-installed device restores tasks and
  calendar history from the database.
- Local data stored under a stale user ID is automatically rebound to the
  current account, with duplicate tasks (by title) and day records (by date)
  merged.
