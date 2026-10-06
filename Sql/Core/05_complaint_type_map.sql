CREATE TABLE core.complaint_type_map (
	raw_label text PRIMARY KEY, 
	conformed_type text NOT NULL,
	note text
);
INSERT INTO core.complaint_type_map (raw_label, conformed_type, note) VALUES
  ('HEATING', 'HEAT/HOT WATER', 'renamed 2014-03'),
  ('Snow', 'SNOW OR ICE', 'DSNY taxonomy migration, Sep 2021'),
  ('Building Marshals office', 'BUILDING MARSHAL''S OFFICE', 'punctuation variant')
ON CONFLICT (raw_label) DO NOTHING;


