#!/bin/bash
# Builds the spike POI database: US eat-and-drink places from Overture Maps,
# queried in place on S3 with DuckDB (the full theme is never downloaded).
# Output: docs/private/places.sqlite  (~1M rows; gitignored)
#         docs/private/places-build.log  (unmapped-subtype counts, per CLAUDE.md)
# Usage: scripts/build-places-db.sh [output.sqlite]
#        OVERTURE_RELEASE=YYYY-MM-DD.N scripts/build-places-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."

RELEASE="${OVERTURE_RELEASE:-2026-08-19.0}"
OUT="${1:-docs/private/places.sqlite}"
LOG="docs/private/places-build.log"
S3="s3://overturemaps-us-west-2/release/${RELEASE}/theme=places/type=place/*.parquet"

mkdir -p docs/private
rm -f "$OUT"
echo "Release ${RELEASE} -> ${OUT}"

duckdb <<SQL
INSTALL httpfs; LOAD httpfs;
INSTALL sqlite; LOAD sqlite;
SET s3_region='us-west-2';
SET preserve_insertion_order=false;

-- categories/basic_category are deprecated; taxonomy.hierarchy is the
-- supported filter (level 1 'food_and_drink' is the eat-and-drink branch).
-- Points carry their coordinate as bbox.xmin/ymin, which avoids the spatial
-- extension entirely. Permanently closed places would only create false
-- matches, so they are dropped.
-- Materialized (not a view) so the S3 scan happens exactly once; the log
-- query below reads the temp table instead of triggering a second scan.
CREATE TEMP TABLE us_food AS
SELECT
  id AS gers_id,
  names."primary" AS name,
  bbox.ymin AS lat,
  bbox.xmin AS lon,
  confidence,
  taxonomy.hierarchy[2] AS level2,
  taxonomy.hierarchy[3] AS level3,
  taxonomy."primary" AS subtype
FROM read_parquet('${S3}')
WHERE taxonomy.hierarchy[1] = 'food_and_drink'
  AND coalesce(operating_status, 'open') <> 'permanently_closed'
  AND names."primary" IS NOT NULL
  AND (
       (bbox.ymin BETWEEN 24.4 AND 49.5 AND bbox.xmin BETWEEN -125.0 AND -66.9)  -- CONUS
    OR (bbox.ymin BETWEEN 51.0 AND 71.6 AND bbox.xmin BETWEEN -179.9 AND -129.9) -- Alaska
    OR (bbox.ymin BETWEEN 18.7 AND 22.5 AND bbox.xmin BETWEEN -160.4 AND -154.7) -- Hawaii
    OR (bbox.ymin BETWEEN 17.6 AND 18.6 AND bbox.xmin BETWEEN -67.4 AND -65.1)   -- Puerto Rico
  );

ATTACH '${OUT}' AS out (TYPE SQLITE);

-- Review-category mapping per CLAUDE.md Places data. cell_* values must match
-- PlaceGrid.cellDegrees in Core/Sources/Places/PlaceGrid.swift.
CREATE TABLE out.places AS
SELECT
  gers_id, name, lat, lon, confidence,
  CASE
    WHEN level2 = 'alcoholic_beverage_venue' THEN 'bar'
    WHEN level2 = 'non_alcoholic_beverage_venue' THEN 'cafe'
    WHEN level2 = 'casual_eatery' AND level3 IN
      ('bakery','dessert_shop','cafe','bagel_shop','candy_store','popcorn_shop') THEN 'cafe'
    WHEN level2 = 'casual_eatery' AND level3 = 'gastropub' THEN 'bar'
    ELSE 'restaurant'
  END AS category,
  subtype,
  CAST(floor(lat / 0.005) AS BIGINT) AS cell_lat,
  CAST(floor(lon / 0.005) AS BIGINT) AS cell_lon
FROM us_food;

COPY (
  SELECT subtype, count(*) AS n FROM us_food
  WHERE level2 IS NULL
     OR level2 NOT IN ('restaurant','casual_eatery','alcoholic_beverage_venue','non_alcoholic_beverage_venue')
  GROUP BY 1 ORDER BY n DESC
) TO '${LOG}' (FORMAT CSV, HEADER);

SELECT category, count(*) AS n FROM out.places GROUP BY 1 ORDER BY n DESC;
SQL

sqlite3 "$OUT" "CREATE INDEX idx_places_cell ON places(cell_lat, cell_lon); ANALYZE;"

echo "Built $OUT:"
sqlite3 "$OUT" "SELECT count(*) || ' places' FROM places;"
ls -lh "$OUT"
