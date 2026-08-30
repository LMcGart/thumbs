-- Plain lat/lon read columns derived from the geography point, so PostgREST
-- selects (profile reviews, feed joins) can return position without an RPC.
alter table places add column lat double precision
  generated always as (st_y(location::geometry)) stored;
alter table places add column lon double precision
  generated always as (st_x(location::geometry)) stored;
