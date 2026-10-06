-- stg/01_service_requests.sql
-- Typed, trimmed, cleaned. One row per raw request; no rows dropped.
--
-- Extract as-of date is hardcoded rather than now(): the source data is a
-- snapshot, so comparing it against a live clock would reclassify rows on
-- every rerun without the data changing. Update this literal on re-extract.

DROP TABLE IF EXISTS stg.service_requests;

CREATE TABLE stg.service_requests AS
WITH typed AS (
  SELECT
    unique_key::bigint                            AS request_id,
    nullif(trim(created_date), '')::timestamp     AS created_at,
    nullif(trim(closed_date),  '')::timestamp     AS closed_at,
    upper(trim(agency))                           AS agency_code,
    trim(complaint_type)                          AS complaint_type_raw,
    nullif(trim(descriptor), '')                  AS descriptor,
    nullif(trim(status), '')                      AS source_status,
    nullif(trim(incident_zip), '')                AS incident_zip,
    nullif(trim(incident_address), '')            AS incident_address,
    CASE WHEN trim(borough) IN ('', 'Unspecified') THEN 'UNKNOWN'
         ELSE upper(trim(borough)) END            AS borough,
    nullif(trim(bbl), '')::bigint                 AS bbl,
    nullif(trim(latitude),  '')::numeric          AS latitude,
    nullif(trim(longitude), '')::numeric          AS longitude
  FROM raw.service_requests
),
flagged AS (
  SELECT
    t.*,
    -- Derived from timestamps, NOT from source_status. The source's own
    -- status field disagrees in places; this column is about whether the
    -- close timestamp is usable.
    CASE
      WHEN t.closed_at IS NULL                          THEN 'open'
      WHEN t.closed_at <  t.created_at                  THEN 'invalid_close'
      WHEN t.closed_at >  TIMESTAMP '2026-08-01'        THEN 'invalid_close'
      ELSE 'closed'
    END AS close_status
  FROM typed t
)
SELECT
  f.*,
  CASE WHEN f.close_status = 'closed'
       THEN round(extract(epoch FROM f.closed_at - f.created_at) / 3600.0, 2)
  END AS resolution_hours
FROM flagged f;

CREATE INDEX ON stg.service_requests (created_at);
CREATE INDEX ON stg.service_requests (complaint_type_raw);
CREATE INDEX ON stg.service_requests (bbl);