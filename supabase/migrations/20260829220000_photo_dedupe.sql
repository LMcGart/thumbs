-- Same source image attached twice to one visit is a no-op: the app checks
-- the source hash before uploading, and this index is the backstop. NULLs
-- (pre-dedupe rows) stay distinct.
alter table photos add column source_hash text;
create unique index photos_visit_source_idx on photos (visit_id, source_hash);
