-- 04_backfill_merge.sql
-- Merges the 2024-06 onward backfill into raw.service_requests.
-- Overlapping months are expected: the extract deliberately re-pulls
-- boundary months, and the anti-join discards what is already present.

CREATE TABLE raw.sr_backfill (LIKE raw.service_requests);

COPY raw.sr_backfill
FROM 'C:/dev/nyc311/ingest/sr_backfill.csv'
WITH (FORMAT csv, HEADER true);

-- Index first. Without it the anti-join does a sequential scan per row.
CREATE INDEX IF NOT EXISTS ix_sr_unique_key
  ON raw.service_requests (unique_key);

-- NOT EXISTS rather than NOT IN: NOT IN returns no rows at all if the
-- subquery yields a single NULL.
INSERT INTO raw.service_requests
SELECT b.*
FROM raw.sr_backfill b
WHERE NOT EXISTS (
  SELECT 1 FROM raw.service_requests s
  WHERE s.unique_key = b.unique_key
);