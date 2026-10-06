Drop table if exists core.dim_date CASCADE;

Create TABLE core.dim_date as

select
to_char(d, 'YYYYMMDD')::int			as dt_key,
d			::date					as date_full,
extract(year from d)::int			as year,
extract(quarter from d)::int		as quarter,
extract(month from d)::int			as month,
EXTRACT(ISODOW FROM d) in (6,7)		as weekend,
CASE 
	WHEN EXTRACT(MONTH FROM d) IN (12, 1, 2) THEN 'Winter'
    WHEN EXTRACT(MONTH FROM d) IN (3, 4, 5) THEN 'Spring'
    WHEN EXTRACT(MONTH FROM d) IN (6, 7, 8) THEN 'Summer'
    ELSE 'Fall'
END AS season

from generate_series('2022-01-01'::date, '2026-12-31'::date, '1 day') as d;


ALTER TABLE core.dim_date ADD PRIMARY KEY (dt_key);

