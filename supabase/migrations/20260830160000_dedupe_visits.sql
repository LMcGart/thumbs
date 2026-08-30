-- One-off data cleanup: early testing created one visit per rating commit.
-- Keep a single visit per (user, place) — the one with the most photos, then
-- the newest — and drop the rest (children cascade). New duplicates can't
-- form: the rating flow reuses the latest visit.
with counts as (
  select v.id, v.user_id, v.place_id, v.visited_at, count(p.id) as photo_count
  from visits v
  left join photos p on p.visit_id = v.id
  group by v.id
), ranked as (
  select id, row_number() over (
    partition by user_id, place_id
    order by photo_count desc, visited_at desc
  ) as rn
  from counts
)
delete from visits where id in (select id from ranked where rn > 1);
