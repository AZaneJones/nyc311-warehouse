-- 02_raw_ddl.sql
-- Landing tables. Every column is TEXT by design: typing here would abort
-- an 8M-row COPY on the first malformed value. Casting happens in stg.

CREATE TABLE raw.taxonomy_census (
  ym             text,
  complaint_type text,
  agency         text,
  n              text
);

CREATE TABLE raw.service_requests (
  unique_key       text,
  created_date     text,
  closed_date      text,
  agency           text,
  complaint_type   text,
  descriptor       text,
  status           text,
  incident_zip     text,
  incident_address text,
  borough          text,
  latitude         text,
  longitude        text,
  bbl              text
);