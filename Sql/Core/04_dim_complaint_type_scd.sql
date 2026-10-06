DROP TABLE IF EXISTS core.dim_complaint_type_scd CASCADE;

CREATE TABLE core.dim_complaint_type_scd (
  complaint_type_key int  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  raw_label          text NOT NULL,
  conformed_type     text NOT NULL,
  agency_key         int  NOT NULL REFERENCES core.dim_agency(agency_key),
  effective_from     date NOT NULL,
  effective_to       date NOT NULL,
  is_current         boolean NOT NULL,
  UNIQUE (raw_label, effective_from)
);

WITH bounds AS (
  SELECT max(ym) AS census_max FROM stg.taxonomy_census
),
dominant AS (
  SELECT DISTINCT ON (complaint_type, ym)
         complaint_type, ym, agency_code
  FROM stg.taxonomy_census
  ORDER BY complaint_type, ym, requests DESC
),
flagged AS (
  SELECT complaint_type, ym, agency_code,
         CASE
           WHEN LAG(agency_code) OVER w IS NULL                    THEN 1
           WHEN LAG(agency_code) OVER w <> agency_code             THEN 1
           WHEN LAG(ym) OVER w < (ym - INTERVAL '12 months')::date THEN 1
           ELSE 0
         END AS is_change
  FROM dominant
  WINDOW w AS (PARTITION BY complaint_type ORDER BY ym)
),
versioned AS (
  SELECT complaint_type, ym, agency_code,
         SUM(is_change) OVER (PARTITION BY complaint_type ORDER BY ym) AS version_id
  FROM flagged
),
collapsed AS (
  SELECT complaint_type, version_id, agency_code,
         min(ym) AS first_month,
         max(ym) AS last_month
  FROM versioned
  GROUP BY complaint_type, version_id, agency_code
),
sequenced AS (
  SELECT c.complaint_type, c.version_id, c.agency_code,
         c.first_month, c.last_month,
         LEAD(c.first_month) OVER w AS next_first_month,
         (LEAD(c.first_month) OVER w IS NULL
          AND c.last_month >= (b.census_max - INTERVAL '12 months')::date) AS is_current
  FROM collapsed c
  CROSS JOIN bounds b
  WINDOW w AS (PARTITION BY c.complaint_type ORDER BY c.version_id)
)
INSERT INTO core.dim_complaint_type_scd
      (raw_label, conformed_type, agency_key, effective_from, effective_to, is_current)
SELECT
  s.complaint_type,
  coalesce(m.conformed_type, upper(trim(s.complaint_type))),
  a.agency_key,
  s.first_month,
  CASE
    WHEN s.next_first_month IS NOT NULL THEN s.next_first_month
    WHEN s.is_current                   THEN 'infinity'::date
    ELSE (s.last_month + INTERVAL '1 month')::date
  END,
  s.is_current
FROM sequenced s
JOIN core.dim_agency a ON a.agency_code = s.agency_code
LEFT JOIN core.complaint_type_map m ON m.raw_label = s.complaint_type;

CREATE INDEX IF NOT EXISTS ix_scd_label_from
  ON core.dim_complaint_type_scd (raw_label, effective_from);