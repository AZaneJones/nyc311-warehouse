# Decisions

Design choices made during the build, with the reasoning behind them.
Grouped by layer rather than chronologically.

## Extraction

### Fact window starts 2022

A 2021 start returned roughly 14M rows. Trimmed to 2022 for tractability.
The taxonomy history that drives the SCD2 dimension comes from a separate
aggregated extract spanning 2010–present, so the shorter fact window costs
nothing there.

### Extraction is chunked by month

Socrata degrades badly on deep `$offset` pagination — the server re-walks
the full result set on each request, so a continuous march through millions
of rows slows until it times out. Month-sized windows keep every offset
small. The original extract died this way and looked complete afterward.

### PLUTO is pulled manually

The tax lot dataset is ~860K rows and fits in a single aggregated request,
so it's a browser download rather than a script. Documented in the
reproduce steps rather than automated.

## Raw layer

### Every column is TEXT

Typing at the landing stage makes ingestion fail on the first malformed
value in 15M rows; casting in `stg` turns those into logged rejects
instead. Load and validate are separate concerns.

### Server-side COPY with absolute paths

`COPY` runs as the Postgres service account and outperforms client-side
loading for local files. The paths are machine-specific and must be edited
before running elsewhere.

## Staging

### Rows with impossible timestamps are kept

13,072 rows have `closed_at` before `created_at`. These rows are retained;
only the derived `resolution_hours` is nulled. Deleting them would have
silently removed valid requests from volume analysis to fix a problem
confined to one derived field.

### close_status is derived from timestamps, not the source status field

The source carries its own status column, which disagrees with the
timestamps in places. `close_status` (open / closed / invalid_close) is
derived solely from whether the close timestamp is usable. The source field
is retained as `source_status` for comparison.

### The validity boundary is the extract as-of date, not now()

Close dates run as late as 2033. The cutoff for "closed in the future" is
the extract's as-of date, hardcoded as a literal. The data is a snapshot;
comparing it against a live clock would reclassify rows on every rerun
without the data changing. `now()` would be correct against a live
operational database.

### Invalid BBLs are excluded from the dimension, not from staging

BBL 0 is a geocoding-failure placeholder carrying hundreds of unrelated
addresses. Left in place it would appear in building-level analysis as a
single building with an impossible complaint history. It is excluded from
`dim_location`, and the fact build routes those requests to a borough
sentinel via `nullif(bbl, 0)`. Staging retains the raw value so the
condition stays auditable.

## Core

### stg and core are tables; rpt is views

Staging casts thirteen columns across 15.8M rows — as a view that cost is
paid on every query, and views cannot be indexed. Materialized once and
indexed on `created_at`, `complaint_type_raw`, and `bbl`. Reporting views
stay views: thin aggregations over an indexed star, cheap to run and never
stale.

### Dimension keys use identity columns with upsert, not ROW_NUMBER

`ROW_NUMBER()` assigns keys positionally, so a rerun after a new value
appears shifts every subsequent key — silently repointing any existing fact
table. Dimensions use `GENERATED ALWAYS AS IDENTITY` with
`ON CONFLICT (natural_key) DO NOTHING`, making the load idempotent and keys
stable across reruns.

### dim_date uses a smart key

`dt_key` is YYYYMMDD rather than a sequence. Dates never change, so the key
cannot drift out of sync with reality, and it survives a full rebuild
unchanged — unlike positional surrogate keys. Kimball allows date as the
exception to the meaningless-surrogate-key rule for this reason.

### dim_date is contiguous with no unknown member

Power BI's "Mark as date table" requires a unique, non-blank, contiguous
date column. A sentinel row breaks contiguity and costs the time
intelligence functions. Unclosed and invalid-close requests carry a NULL
`closed_date_key` instead; SQL handles that with LEFT JOIN and Power BI
surfaces it as a blank member — more honest than hiding those rows behind
a filter.

### dim_location uses six sentinel members

The opposite call from `dim_date`, deliberately. Roughly 1.9M requests have
no building attribution — largely public-space complaints, though the split
between "not a building" and "geocoding failed" can't be determined without
the `location_type` field, which wasn't extracted. Borough is a primary
slicer, so collapsing all of them into one UNKNOWN member would silently
drop 12% of rows from every borough chart. Instead, BBL -1 through -5 mirror
the borough codes (a real BBL's first digit is the borough, 1–5), with -9
for unknown borough. Building-level analysis scopes to positive BBLs;
borough-level analysis covers all 15.8M rows.

### dim_location grain is the tax lot (BBL), not the address

Addresses are unnormalized in the source — "240 1 AVE", "240 1 AVENUE",
and "240 FIRST AVENUE" all appear for the same building. BBL groups them
correctly without string matching. BBL is a tax lot rather than a building,
so large complexes collapse to one row — which is the right unit for
chronic-problem analysis, since a tax lot is an ownership and management
unit.

### One representative row per BBL

706,675 distinct BBLs produce 1,106,633 distinct combinations of BBL,
address, ZIP, and coordinates — mostly address spelling variance and
geocoding jitter. A naive SELECT DISTINCT would add ~400,000 phantom
dimension rows and fan out the fact join. A representative row is chosen per
BBL with `DISTINCT ON` rather than aggregating columns independently, which
would let latitude and longitude come from different records and produce a
coordinate that never existed.

### PLUTO joined to normalize complaint counts

Raw complaint counts by building measure building size, not problem
severity: StuyTown (11,000+ residents on one tax lot) tops any volume
ranking against a 20-unit walkup. PLUTO joins on BBL and supplies
residential units, building area, floors, year built, and building class,
allowing per-unit rates. 99.6% of BBLs match. `nullif(units_res, 0)` guards
the denominator, since non-residential lots legitimately have zero units.

### Owner names are excluded; portfolio size is derived instead

PLUTO publishes owner names, and the interesting question is whether large
landlords have worse complaint rates. But the source data being public
record is not the same as republishing it in a dashboard that ranks named
individuals. Owner name stays in `stg.pluto`; `dim_location` carries only a
`portfolio_band` derived from it. Note that NYC landlords routinely register
each building to a separate LLC, so registered ownership concentration
undercounts real portfolios — the measure is registered ownership, not
beneficial ownership.

### dim_agency is backfilled from the taxonomy census

Built initially from `stg.service_requests` (2022+), which yielded 19
agencies. The census spans 2010–present and contains 17 more that no longer
appear — renamed, merged, or dissolved. Without them a foreign key from the
SCD2 dimension would reject historical rows. The upsert pattern made this a
single additional INSERT with no key churn.

### Seasonal categories lag their own rename dates

Because the taxonomy is inferred from complaint volume, a seasonal category's
`effective_from` reflects when it was first *observed*, not when it changed.
DSNY's migration occurred in September 2021, but `Snow or Ice` does not appear
until October — there was nothing to file in between. This is a limitation of
inferring a taxonomy from volume data rather than from a system catalog.

### Only 1:1 renames are conformed

`conformed_type` maps a raw label to a canonical one, defaulting to
`upper(trim(raw_label))` so casing and whitespace variants collapse without
any curation. Explicit mappings are added only where a rename is verifiable
(`HEATING` → `HEAT/HOT WATER`). The September 2021 DSNY restructure is left
unconformed: eighteen labels retired against eighteen created on the same
date, and no mapping between them is recoverable from the data. Asserting one
would have been a fabrication dressed as completeness.

## Analysis scope

### Cohort scope is complaint type, not BBL presence

"Has a BBL" looked like a clean proxy for building-attached complaints, but
banding complaint types by their missing-BBL rate showed otherwise: only two
types sit above 95% missing, 51 below 10%, and 40 in between. BBL presence
tracks how a request was located (address vs. intersection), not what it was
about. Cohort analysis therefore scopes to complaint types that are
inherently building-attached rather than filtering on missingness.

### Agency handoffs are not a finding in this data

An initial pass suggested two complaint types changed handling agency inside
the fact window. Inspecting the monthly detail showed neither was a transfer:
Plumbing is permanently co-handled by DOB and HPD, and HPD merely
out-volumed DOB for two months during a 2023 spike; Asbestos is DEP
throughout with one month where DOHMH edged ahead by a handful of requests.
Under any persistence threshold there are zero genuine handoffs post-2022.
The "dominant agency" heuristic was measuring which agency had a bigger
month, not who owned the complaint type.

### The SCD2 dimension versions on label lifecycle, not agency

Of 185 complaint types above 5,000 requests, only 72 span the full 2010–2026
window. 48 appear partway through, 43 stop before the end, and 22 both
appear and disappear — 61% churn. 5M requests belong to labels that no
longer exist. That churn, not agency ownership, is what the dimension needs
to track.

### Taxonomy drift is event-shaped, not pairwise

A self-join looking for 1:1 renames produced mostly coincidental pairs. The
real pattern is mass migration: roughly ten DSNY labels die in September 2021
while thirteen new DSNY labels appear in the same window, with several
obvious correspondences (Litter Basket / Request → Litter Basket Request,
Derelict Bicycle → Abandoned Bike, Sweeping/Missed → Street Sweeping
Complaint). Sanitation replaced its entire 311 taxonomy at once. Any naive
time series of DSNY complaint types shows a cliff at that date that isn't
real.

### COVID-era complaint types are not conformed

Five complaint types appear and disappear with the pandemic — non-essential
construction (March 2020), phased reopening non-compliance (June 2020 to
July 2021), vaccine mandate non-compliance (August 2021 onward). Unlike the
DSNY relabeling, these have no predecessor and no successor: they are
genuine births and deaths. Conforming them to anything would be a
fabrication. Their bounded effective ranges are the truth.

### A gap in the census ends a version

If a complaint type disappears from the census for a stretch and returns,
that ends the version and the return starts a new one — rather than treating
the absence as continuity. This makes the change-detection rule test both
whether the agency changed and whether the previous row is the immediately
preceding month.

## Presentation

### One data source per workbook

Three separate workbooks rather than one: census-sourced taxonomy drift,
star-schema operational (Power BI), and star-schema executive (Tableau).
Mixing sources in a single workbook obscures lineage.

### Power BI imports the star; Tableau consumes flattened views

Power BI's engine is optimized for star schemas, so it imports the
dimensional tables directly and models relationships in-tool. Tableau's
extract engine prefers wide, denormalized tables, so it reads flattened
`rpt` views. One governed SQL layer, consumed idiomatically by each tool.

### Universal date parts belong to the BI tool; business-defined ones to SQL

Month names and year-month labels are not materialized. Tableau builds a
date hierarchy automatically from a real date column, and materialized text
parts fight it. `season` stays in SQL because meteorological vs.
astronomical is a choice someone made, and a decision implemented in two
tools will eventually be implemented two different ways.