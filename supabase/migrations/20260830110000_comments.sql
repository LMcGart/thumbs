-- Comments on visits (scope addition 2026-08-29): visible wherever the visit
-- is visible, writable by anyone who can see it, deletable by their author.
create table comments (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references visits (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index comments_visit_idx on comments (visit_id);

alter table comments enable row level security;
create policy comments_select on comments for select to authenticated
  using (can_see_visit(visit_id));
create policy comments_insert on comments for insert to authenticated
  with check (user_id = auth.uid() and can_see_visit(visit_id));
create policy comments_delete on comments for delete to authenticated
  using (user_id = auth.uid());
