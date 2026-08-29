-- Thumbs v1 schema (roadmap item 4). PostGIS for places; everything else plain.
create extension if not exists postgis;

-- 1:1 with auth.users; created by trigger on signup. handle is set later by
-- the user (anonymous dev users start without one).
create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  handle text unique,
  display_name text,
  avatar_path text,
  created_at timestamptz not null default now()
);

create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

create table friendships (
  requester uuid not null references profiles (id) on delete cascade,
  addressee uuid not null references profiles (id) on delete cascade,
  status text not null default 'requested' check (status in ('requested', 'accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- Our own IDs; GERS and MapKit ids are secondary columns (never the primary key).
create table places (
  id bigint generated always as identity primary key,
  gers_id text unique,
  mapkit_id text unique,
  name text not null,
  location geography (point, 4326) not null,
  category text not null check (category in ('restaurant', 'cafe', 'bar')),
  subtype text,
  source_confidence double precision,
  created_at timestamptz not null default now()
);
create index places_location_idx on places using gist (location);
-- Prefix search (item 5): lower(name) LIKE 'lu%'
create index places_name_prefix_idx on places (lower(name) text_pattern_ops);

create table visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  place_id bigint not null references places (id),
  visited_at timestamptz not null,
  source text not null check (source in ('detected', 'manual')),
  created_at timestamptz not null default now()
);
create index visits_user_idx on visits (user_id, visited_at desc);
create index visits_place_idx on visits (place_id);

-- One rating per visit; category captured at rating time because a place can
-- be recategorized later (CLAUDE.md Rating spec).
create table ratings (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null unique references visits (id) on delete cascade,
  score smallint not null check (score between 1 and 10),
  category text not null check (category in ('restaurant', 'cafe', 'bar')),
  created_at timestamptz not null default now()
);

create table dish_ratings (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references visits (id) on delete cascade,
  dish_name text not null,
  verdict text not null check (verdict in ('must', 'good', 'skip')),
  created_at timestamptz not null default now()
);
create index dish_ratings_visit_idx on dish_ratings (visit_id);

create table photos (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references visits (id) on delete cascade,
  storage_path text not null,
  tier_sizes jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index photos_visit_idx on photos (visit_id);

-- Reservation drop rules (item 11); rows come from the user-verified CSV.
create table drop_rules (
  id uuid primary key default gen_random_uuid(),
  place_id bigint not null references places (id),
  platform text,
  rule_type text not null,
  window_days int,
  time_local time,
  weekday smallint check (weekday between 0 and 6),
  phone text,
  url text,
  confidence text,
  verified_on date,
  created_at timestamptz not null default now()
);
create index drop_rules_place_idx on drop_rules (place_id);

create table reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  place_id bigint not null references places (id),
  rule_id uuid references drop_rules (id) on delete set null,
  desired_date date not null,
  drop_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index reminders_user_idx on reminders (user_id);
