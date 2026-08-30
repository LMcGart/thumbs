-- Likes on reviews (visits) and comments: exactly one target per row, one
-- like per user per target, visible wherever the target is visible.
create function can_see_comment(comment uuid) returns boolean
language sql stable as $$
  select exists (
    select 1 from comments c where c.id = comment and can_see_visit(c.visit_id)
  );
$$;

create table likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  visit_id uuid references visits (id) on delete cascade,
  comment_id uuid references comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  check ((visit_id is null) <> (comment_id is null)),
  unique (user_id, visit_id),
  unique (user_id, comment_id)
);
create index likes_visit_idx on likes (visit_id);
create index likes_comment_idx on likes (comment_id);

alter table likes enable row level security;
create policy likes_select on likes for select to authenticated
  using ((visit_id is not null and can_see_visit(visit_id))
      or (comment_id is not null and can_see_comment(comment_id)));
create policy likes_insert on likes for insert to authenticated
  with check (user_id = auth.uid()
      and ((visit_id is not null and can_see_visit(visit_id))
        or (comment_id is not null and can_see_comment(comment_id))));
create policy likes_delete on likes for delete to authenticated
  using (user_id = auth.uid());
