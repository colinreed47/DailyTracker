-- Allow the requester to cancel (delete) their own pending friendship request
create policy "Requester can delete own friendship requests"
  on public.friendships for delete
  using (auth.uid() = requester_id);
