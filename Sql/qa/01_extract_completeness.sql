-- qa/01_extract_completeness.sql
-- Reconciles monthly row counts in raw.service_requests against the
-- independently aggregated taxonomy census to detect extract gaps.
-- min/max on created_date does NOT reveal these gaps: a few thousand
-- outlier rows made two years of missing data look present.
--
-- Run once as 'pre_backfill'. Re-run with the label changed to
-- 'post_backfill' after sql/04_backfill_merge.sql.

CREATE TABLE IF NOT EXISTS qa.extract_completeness (
  snapshot_label text,
  captured_at    timestamptz DEFAULT now(),
  ym             text,
  census_rows    bigint,
  fact_rows      bigint,
  pct_complete   numeric
);

INSERT INTO qa.extract_completeness
      (snapshot_label, ym, census_rows, fact_rows, pct_complete)
WITH fact AS (
  SELECT left(created_date, 7) AS ym, count(*) AS fact_rows
  FROM raw.service_requests
  GROUP BY 1
),
census AS (
  SELECT left(ym, 7) AS ym, sum(n::int) AS census_rows
  FROM raw.taxonomy_census
  WHERE ym >= '2022'
  GROUP BY 1
)
SELECT 'pre_backfill', c.ym, c.census_rows, f.fact_rows,
       round(100.0 * coalesce(f.fact_rows, 0) / c.census_rows, 1)
FROM census c
LEFT JOIN fact f USING (ym);