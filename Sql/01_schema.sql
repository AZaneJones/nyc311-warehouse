-- 01_schemas.sql
-- Creates the layer schemas. Run against the nyc311 database.
-- Database itself is created separately: CREATE DATABASE nyc311;

CREATE SCHEMA IF NOT EXISTS raw;   -- landing zone, all TEXT
CREATE SCHEMA IF NOT EXISTS stg;   -- typed, cleaned, conformed
CREATE SCHEMA IF NOT EXISTS core;  -- dimensional model
CREATE SCHEMA IF NOT EXISTS rpt;   -- reporting views for dashboards
CREATE SCHEMA IF NOT EXISTS qa;    -- retained data quality audits