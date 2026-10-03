# Verified SQL outputs

These CSVs were generated from the intermediate PostgreSQL scripts and the five original source CSVs. Run `sql/09_export_results.sql` with `psql` after completing scripts 00–08 to refresh them. Output paths default to `/reports/results/` in the documented Docker setup.

The telemetry file reports **percentage changes**, not standardized shifts. The maintenance age file reports time since the **latest earlier replacement among components that failed**, not a survival estimate. Priority groups use score cutoffs, not quartiles.

The static HTML report and figures are snapshots of these verified results and are not automatically rebuilt by the SQL export commands.
