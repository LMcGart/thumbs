-- Item 5: server-side search. Name-prefix match (uses places_name_prefix_idx)
-- ranked by distance from a bias point (NYC default). address is filled for
-- MapKit-added places; Overture rows reverse-geocode on demand client-side.
alter table places add column address text;

create function search_places(
  query text,
  near_lat double precision default 40.7291,
  near_lon double precision default -73.9965,
  max_results int default 20
)
returns table (
  id bigint,
  name text,
  category text,
  subtype text,
  address text,
  lat double precision,
  lon double precision,
  distance_meters double precision
)
language sql stable
set search_path = public
as $$
  select p.id, p.name, p.category, p.subtype, p.address,
         st_y(p.location::geometry),
         st_x(p.location::geometry),
         st_distance(p.location, st_point(near_lon, near_lat)::geography)
  from places p
  where lower(p.name) like
    lower(replace(replace(replace(query, '\', '\\'), '%', '\%'), '_', '\_')) || '%'
  order by st_distance(p.location, st_point(near_lon, near_lat)::geography)
  limit greatest(1, least(max_results, 50));
$$;
