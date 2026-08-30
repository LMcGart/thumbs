-- One-level comment threading: a reply points at its parent comment and
-- disappears with it. Visibility/write rules are unchanged.
alter table comments add column parent_id uuid references comments (id) on delete cascade;
create index comments_parent_idx on comments (parent_id);
