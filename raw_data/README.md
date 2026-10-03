# Source data setup

Download the synthetic [Microsoft Azure Predictive Maintenance dataset](https://www.kaggle.com/datasets/arnabbiswas1/microsoft-azure-predictive-maintenance), published in a Kaggle mirror by Arnab Biswas.

Extract the archive and place these files directly in this folder:

| File | Expected records | Loaded table |
| --- | ---: | --- |
| `PdM_machines.csv` | 100 | `machines` |
| `PdM_telemetry.csv` | 876,100 | `telemetry` |
| `PdM_errors.csv` | 3,919 | `errors` |
| `PdM_maint.csv` | 3,286 | `maintenance` |
| `PdM_failures.csv` | 761 | `failures` |

The source column `machineID` is loaded into `machine_id`; telemetry and event timestamps use `datetime`. CSV loading uses the explicit column order in `sql/01_load_data.sql`, and skips the source header.

The Docker command in the root README mounts this folder at `/data` on the database server. For PostgreSQL installed locally, change the five server-side `COPY` paths to the absolute paths of your files. The PostgreSQL process needs read access.

This repository excludes source CSVs, downloaded archives and account credentials. Source data remain subject to the dataset publisher’s terms; this repository’s MIT license covers code and documentation.
