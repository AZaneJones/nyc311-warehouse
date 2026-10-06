-- 03_raw_load.sql
-- Server-side COPY. Paths are absolute and machine-specific — edit before running. 
--The Postgres service account must be able to read the folder.

COPY raw.taxonomy_census
FROM 'C:/dev/nyc311/ingest/taxonomy_census.csv' -- <- This is what's on my machine. Your machine is not my machine. Make sure your path makes sense.
WITH (FORMAT csv, HEADER true);

COPY raw.service_requests
FROM 'C:/dev/nyc311/ingest/sr_2022_present.csv' -- <- This is what's on my machine. Your machine is not my machine. Make sure your path makes sense.
WITH (FORMAT csv, HEADER true);