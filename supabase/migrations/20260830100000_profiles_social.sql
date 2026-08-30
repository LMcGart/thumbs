-- Item 8: profile handles and avatar storage.
-- Handles are the friend-request address: lowercase, url-safe, 3-20 chars.
alter table profiles add constraint profiles_handle_format
  check (handle ~ '^[a-z0-9_]{3,20}$');

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', false)
on conflict (id) do nothing;

-- Any signed-in user can see avatars (profiles are readable app-wide);
-- each user writes only their own, at a fixed path.
create policy avatar_objects_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars');
create policy avatar_objects_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name = 'users/' || auth.uid()::text || '.heic');
create policy avatar_objects_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and name = 'users/' || auth.uid()::text || '.heic');
create policy avatar_objects_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and name = 'users/' || auth.uid()::text || '.heic');
