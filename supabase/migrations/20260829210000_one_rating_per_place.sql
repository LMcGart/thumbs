-- Product decision (2026-08-29): one editable rating per user per place.
-- Visits remain the activity log (feed, photos, dishes, detection); the
-- rating moves off the visit onto (user, place) and is edited in place.
alter table ratings add column user_id uuid references profiles (id) on delete cascade;
alter table ratings add column place_id bigint references places (id);

update ratings set user_id = v.user_id, place_id = v.place_id
from visits v where ratings.visit_id = v.id;

-- Collapse existing per-visit ratings, keeping the newest per (user, place);
-- ctid breaks created_at ties from bulk seeds.
delete from ratings older using ratings newer
where older.user_id = newer.user_id
  and older.place_id = newer.place_id
  and (older.created_at < newer.created_at
       or (older.created_at = newer.created_at and older.ctid < newer.ctid));

alter table ratings alter column user_id set not null;
alter table ratings alter column place_id set not null;
alter table ratings add constraint ratings_one_per_user_place unique (user_id, place_id);
drop policy ratings_select on ratings;
drop policy ratings_insert on ratings;
drop policy ratings_update on ratings;
drop policy ratings_delete on ratings;

alter table ratings drop column visit_id;
alter table ratings add column updated_at timestamptz not null default now();

create policy ratings_select on ratings for select to authenticated
  using (user_id = auth.uid() or is_friend(user_id));
create policy ratings_insert on ratings for insert to authenticated
  with check (user_id = auth.uid());
create policy ratings_update on ratings for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy ratings_delete on ratings for delete to authenticated
  using (user_id = auth.uid());
