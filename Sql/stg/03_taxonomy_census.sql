-- stg/03_taxonomy_census.sql
-- Typed taxonomy census: one row per complaint type × agency × month,
-- 2010-present. Source for dim_complaint_type_scd.
-- agency is upper(trim())'d to match stg.service_requests, so the same
-- code never appears twice under different casing.

DROP TABLE IF EXISTS stg.taxonomy_census;

CREATE TABLE stg.taxonomy_census AS
SELECT
  nullif(trim(ym), '')::date         AS ym,
  trim(complaint_type)               AS complaint_type,
  upper(trim(agency))                AS agency_code,
  nullif(trim(n), '')::int           AS requests
FROM raw.taxonomy_census
WHERE nullif(trim(complaint_type), '') IS NOT NULL
  AND nullif(trim(agency), '') IS NOT NULL;

CREATE INDEX ON stg.taxonomy_census (complaint_type, ym);