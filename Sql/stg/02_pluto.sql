-- stg/02_pluto.sql
-- Typed PLUTO. One row per tax lot; the PK on bbl enforces that.
-- yearbuilt uses 0 for unknown in PLUTO, so it's nulled explicitly.

DROP TABLE IF EXISTS stg.pluto;

CREATE TABLE stg.pluto AS
SELECT
  nullif(trim(bbl), '')::numeric::bigint         AS bbl,
  nullif(trim(unitsres), '')::numeric::int       AS units_res,
  nullif(trim(unitstotal), '')::numeric::int     AS units_total,
  nullif(trim(bldgarea), '')::numeric            AS bldg_area,
  nullif(trim(numfloors), '')::numeric           AS num_floors,
  nullif(nullif(trim(yearbuilt), '')::numeric::int, 0) AS year_built,
  nullif(trim(bldgclass), '')                    AS bldg_class,
  nullif(trim(ownername), '')                    AS owner_name,
  
FROM raw.pluto
WHERE nullif(trim(bbl), '') IS NOT NULL;

ALTER TABLE stg.pluto ADD PRIMARY KEY (bbl);