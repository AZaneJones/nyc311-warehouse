-- 05_pluto_raw.sql
-- PLUTO tax lot data (Socrata 64uk-42ks), used to normalize complaint
-- counts per residential unit. Column order must match the $select
-- order used in the download URL.

CREATE TABLE IF NOT EXISTS raw.pluto (
  bbl         text,
  unitsres    text,
  unitstotal  text,
  bldgarea    text,
  numfloors   text,
  yearbuilt   text,
  bldgclass   text,
  ownername   text
);

COPY raw.pluto
FROM 'C:/dev/nyc311/ingest/pluto.csv'
WITH (FORMAT csv, HEADER true);