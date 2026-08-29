-- RLS (roadmap item 4): a user reads their own rows and rows of accepted
-- friends; writes only their own. Reference data (places, drop_rules) is
-- readable by any signed-in user. Profiles are readable by any signed-in user
-- — a deliberate exception, since friend requests look people up by handle
-- before any friendship exists; profiles carry only handle/name/avatar.

-- security definer so policies on other tables can consult friendships
-- without recursing into its own RLS.
create function is_friend(other uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester = auth.uid() and addressee = other)
        or (requester = other and addressee = auth.uid()))
  );
$$;

alter table profiles enable row level security;
alter table friendships enable row level security;
alter table places enable row level security;
alter table visits enable row level security;
alter table ratings enable row level security;
alter table dish_ratings enable row level security;
alter table photos enable row level security;
alter table drop_rules enable row level security;
alter table reminders enable row level security;

create policy profiles_select on profiles for select to authenticated
  using (true);
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

create policy friendships_select on friendships for select to authenticated
  using (requester = auth.uid() or addressee = auth.uid());
create policy friendships_insert on friendships for insert to authenticated
  with check (requester = auth.uid() and status = 'requested');
-- Only the addressee can accept.
create policy friendships_update on friendships for update to authenticated
  using (addressee = auth.uid()) with check (addressee = auth.uid());
create policy friendships_delete on friendships for delete to authenticated
  using (requester = auth.uid() or addressee = auth.uid());

-- Shared POI reference data: anyone signed in can read; inserts allowed so
-- users can add places from MapKit results (item 5); no update/delete.
create policy places_select on places for select to authenticated
  using (true);
create policy places_insert on places for insert to authenticated
  with check (true);

create policy visits_select on visits for select to authenticated
  using (user_id = auth.uid() or is_friend(user_id));
create policy visits_insert on visits for insert to authenticated
  with check (user_id = auth.uid());
create policy visits_update on visits for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy visits_delete on visits for delete to authenticated
  using (user_id = auth.uid());

-- ratings/dish_ratings/photos hang off a visit: visibility and ownership
-- follow the visit's owner.
create function owns_visit(visit uuid) returns boolean
language sql stable as $$
  select exists (select 1 from visits where id = visit and user_id = auth.uid());
$$;

create function can_see_visit(visit uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from visits
    where id = visit and (user_id = auth.uid() or is_friend(user_id))
  );
$$;

create policy ratings_select on ratings for select to authenticated
  using (can_see_visit(visit_id));
create policy ratings_insert on ratings for insert to authenticated
  with check (owns_visit(visit_id));
create policy ratings_update on ratings for update to authenticated
  using (owns_visit(visit_id)) with check (owns_visit(visit_id));
create policy ratings_delete on ratings for delete to authenticated
  using (owns_visit(visit_id));

create policy dish_ratings_select on dish_ratings for select to authenticated
  using (can_see_visit(visit_id));
create policy dish_ratings_insert on dish_ratings for insert to authenticated
  with check (owns_visit(visit_id));
create policy dish_ratings_update on dish_ratings for update to authenticated
  using (owns_visit(visit_id)) with check (owns_visit(visit_id));
create policy dish_ratings_delete on dish_ratings for delete to authenticated
  using (owns_visit(visit_id));

create policy photos_select on photos for select to authenticated
  using (can_see_visit(visit_id));
create policy photos_insert on photos for insert to authenticated
  with check (owns_visit(visit_id));
create policy photos_delete on photos for delete to authenticated
  using (owns_visit(visit_id));

-- Drop rules are shared reference data; rows are seeded server-side only.
create policy drop_rules_select on drop_rules for select to authenticated
  using (true);

create policy reminders_select on reminders for select to authenticated
  using (user_id = auth.uid());
create policy reminders_insert on reminders for insert to authenticated
  with check (user_id = auth.uid());
create policy reminders_update on reminders for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reminders_delete on reminders for delete to authenticated
  using (user_id = auth.uid());
