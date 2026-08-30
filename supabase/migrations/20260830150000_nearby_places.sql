-- Radius match for onboarding detection: places within `radius_m` of a
-- cluster centroid, nearest first (GiST-indexed st_dwithin).
create function nearby_places(
  near_lat double precision,
  near_lon double precision,
  radius_m double precision default 75,
  max_results int default 10
)
returns table (
  id bigint,
  name text,
  category text,
  subtype text,
  address text,
  lat double precision,
  lon double precision,
  distance_meters double precision,
  confidence double precision
)
language sql stable
set search_path = public
as $$
  select p.id, p.name, p.category, p.subtype, p.address, p.lat, p.lon,
         st_distance(p.location, st_point(near_lon, near_lat)::geography),
         p.source_confidence
  from places p
  where st_dwithin(p.location, st_point(near_lon, near_lat)::geography, radius_m)
  order by st_distance(p.location, st_point(near_lon, near_lat)::geography)
  limit greatest(1, least(max_results, 25));
$$;
