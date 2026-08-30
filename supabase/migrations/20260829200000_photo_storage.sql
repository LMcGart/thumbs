-- Item 7: photo storage. Private bucket; object paths are
-- visits/{visitId}/{photoId}/{tier}.heic and visibility follows the visit's
-- visibility (owner writes, accepted friends read) via the same helpers as
-- the photos table.
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

create policy photo_objects_insert on storage.objects for insert to authenticated
  with check (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = 'visits'
    and exists (
      select 1 from public.visits
      where id = ((storage.foldername(name))[2])::uuid and user_id = auth.uid()
    )
  );

create policy photo_objects_select on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = 'visits'
    and public.can_see_visit(((storage.foldername(name))[2])::uuid)
  );

create policy photo_objects_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = 'visits'
    and exists (
      select 1 from public.visits
      where id = ((storage.foldername(name))[2])::uuid and user_id = auth.uid()
    )
  );
