-- core/06_fact_service_request.sql
-- Grain: one row per request
-- complaint_type_key uses an as-of join: requests pick the dim version in effect on the created date rather than current version

DROP TABLE IF EXISTS core.fact_service_request; 

CREATE TABLE core.fact_service_request (
	request_id			bigint PRIMARY KEY,
	created_date_key	int NOT NULL REFERENCES core.dim_date(dt_key),
	closed_date_key		int REFERENCES core.dim_date(dt_key),
	complaint_type_key	int REFERENCES core.dim_complaint_type_scd(complaint_type_key),
	agency_key			int	NOT NULL REFERENCES core.dim_agency(agency_key), 
	location_key		int NOT NULL REFERENCES core.dim_location(location_key),
	close_status		text NOT NULL,
	resolution_hours	numeric
);

SET work_mem = '256MB';

INSERT INTO core.fact_service_request
		(request_id, created_date_key, closed_date_key, complaint_type_key, agency_key, location_key, close_status, resolution_hours
		)
SELECT 
	s.request_id,
	to_char(s.created_at, 'YYYYMMDD'):: int,
	CASE WHEN s.close_status = 'closed'
		THEN to_char(s.closed_at, 'YYYYMMDD'):: int END,
	d.complaint_type_key,
	a.agency_key,
	l.location_key,
	s.close_status,
	s.resolution_hours
FROM (
	SELECT sr.*,
		coalesce(nullif(sr.bbl, 0), CASE sr.borough
			WHEN 'MANHATTAN'		THEN -1
			WHEN 'BRONX'			THEN -2
			WHEN 'BROOKLYN'			THEN -3
			WHEN 'QUEENS'			THEN -4
			WHEN 'STATEN ISLAND'	THEN -5
			ELSE -9 END) AS lookup_bbl
	FROM stg.service_requests sr
) s
LEFT JOIN core.dim_agency a ON a.agency_code = s.agency_code
LEFT JOIN core.dim_location l ON l.bbl 	= s.lookup_bbl
LEFT JOIN core.dim_complaint_type_scd d
		on d.raw_label = s.complaint_type_raw
		AND s.created_at >= d.effective_from
		and s.created_at < d.effective_to;
		
CREATE INDEX ON core.fact_service_request (created_date_key);
CREATE INDEX ON core.fact_service_request (complaint_type_key);
CREATE INDEX ON core.fact_service_request (location_key);
CREATE INDEX ON core.fact_service_request (agency_key);
