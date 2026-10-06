-- core/02_dim_agency.sql
-- Agency dimension. Two sources, because neither covers the full range:
--   stg.service_requests spans 2022-present (19 agencies)
--   stg.taxonomy_census spans 2010-present and adds 17 more that were
--   renamed, merged, or dissolved before the fact window opens
-- Without the second insert, a foreign key from dim_complaint_type_scd
-- rejects every historical version.
--
-- Idempotent: ON CONFLICT means existing agency_key values never shift,
-- so a rerun cannot silently repoint the fact table.
--
-- Depends on stg/01_service_requests.sql and stg/03_taxonomy_census.sql.

CREATE TABLE IF NOT EXISTS core.dim_agency (
  agency_key  int  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  agency_code text NOT NULL UNIQUE
);

-- Agencies appearing in the fact window
INSERT INTO core.dim_agency (agency_code)
SELECT agency_code
FROM stg.service_requests
WHERE agency_code IS NOT NULL
GROUP BY agency_code
ON CONFLICT (agency_code) DO NOTHING;

-- Historical agencies from the taxonomy census
INSERT INTO core.dim_agency (agency_code)
SELECT agency_code
FROM stg.taxonomy_census
WHERE agency_code IS NOT NULL
GROUP BY agency_code
ON CONFLICT (agency_code) DO NOTHING;
