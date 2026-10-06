CREATE TABLE if NOT EXISTS core.dim_location (
  location_key  int  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bbl bigint NOT NULL UNIQUE,
  borough text,
  zip_code text,
  latitude numeric,
  longitude numeric,
  address text,
  residential_units int,
  lot_units int,
  building_area numeric,
  floors numeric,
  build_year int,
  building_class text,
  portfolio_band text
);

WITH owner_portfolio as (
	SELECT owner_name, count(*) as bbl_count
	FROM stg.pluto
	WHERE units_res > 0
	AND owner_name NOT IN ('NAME NOT ON FILE', 'UNAVAILABLE OWNER')
	group by owner_name
	
)

INSERT INTO core.dim_location (bbl, borough, zip_code, latitude, longitude, address, residential_units, lot_units, 
								building_area, floors, build_year, Building_class, portfolio_band)

								
SELECT DISTINCT ON (bbl)
       bbl, borough, incident_zip, latitude, longitude, incident_address, units_res, units_total, bldg_area, 
	   num_floors, year_built, bldg_class, 
	   case
	   		WHEN bbl_count IS NULL THEN 'unknown'
			when bbl_count = 1 then 		'1'
			when  bbl_count <= 5 then '2-5' 
			when bbl_count <= 20 then '6-20'
			when bbl_count <=50 then '21-50'
			when bbl_count <=100 then '51-100'
			else '101+'
				END
	   as portfolio_band
FROM stg.service_requests LEFT JOIN stg.pluto p USING (bbl)
							LEFT JOIN owner_portfolio op on op.owner_name = p.owner_name 
WHERE bbl IS NOT NULL
ORDER BY bbl,
         (latitude IS NULL OR longitude IS NULL),
         created_at DESC,
         request_id
ON CONFLICT (bbl) DO NOTHING;

INSERT INTO core.dim_location (bbl, borough, portfolio_band)
VALUES
  (-1, 'MANHATTAN',     'n/a'),
  (-2, 'BRONX',         'n/a'),
  (-3, 'BROOKLYN',      'n/a'),
  (-4, 'QUEENS',        'n/a'),
  (-5, 'STATEN ISLAND', 'n/a'),
  (-9, 'UNKNOWN',       'n/a')
ON CONFLICT (bbl) DO NOTHING;
