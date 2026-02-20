# SQL Layer

All queries are written for DuckDB and executed via the Python `duckdb` library within the notebooks. Run files in the numbered order below — each builds on the outputs of the previous.

| Order | File | Description |
|-------|------|-------------|
| 0 | `00_validation.sql` | Sanity checks on raw data after simulation |
| 1 | `01_staging.sql` | Deduplication, type casting, clean views |
| 2 | `02_journey_reconstruction.sql` | User path reconstruction using window functions |
| 3 | `03_experiment_validation.sql` | Balance checks, SUTVA validation, contamination detection |
| 4 | `04_analysis_datasets.sql` | Final flattened tables for Python notebooks |

Processed outputs are written to `/data/processed/` as CSVs and committed to the repo so notebooks can be run without re-executing the full SQL pipeline.
