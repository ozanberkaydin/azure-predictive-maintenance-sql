-- Step 2: Load all five CSVs. COPY reads files on the database SERVER.
-- Docker: mount raw_data at /data. Local server: edit the five absolute paths.
-- DataGrip can execute this file when the server has access to those paths.
-- PK, FK and CHECK constraints reject invalid data; the transaction is atomic.
BEGIN;
SET LOCAL datestyle = 'ISO, MDY';
TRUNCATE TABLE failures, maintenance, errors, telemetry, machines;
COPY machines (machine_id, model, age)
FROM '/data/PdM_machines.csv' WITH (FORMAT csv, HEADER true);
COPY telemetry (datetime, machine_id, volt, rotate, pressure, vibration)
FROM '/data/PdM_telemetry.csv' WITH (FORMAT csv, HEADER true);
COPY errors (datetime, machine_id, error_id)
FROM '/data/PdM_errors.csv' WITH (FORMAT csv, HEADER true);
COPY maintenance (datetime, machine_id, component)
FROM '/data/PdM_maint.csv' WITH (FORMAT csv, HEADER true);
COPY failures (datetime, machine_id, component)
FROM '/data/PdM_failures.csv' WITH (FORMAT csv, HEADER true);
COMMIT;

-- Compare with the source counts. A mismatch is visible, not an automatic abort.
SELECT 'machines' AS table_name, COUNT(*) AS row_count, 100 AS expected_count FROM machines
UNION ALL SELECT 'telemetry', COUNT(*), 876100 FROM telemetry
UNION ALL SELECT 'errors', COUNT(*), 3919 FROM errors
UNION ALL SELECT 'maintenance', COUNT(*), 3286 FROM maintenance
UNION ALL SELECT 'failures', COUNT(*), 761 FROM failures
ORDER BY table_name;
ANALYZE machines;
ANALYZE telemetry;
ANALYZE errors;
ANALYZE maintenance;
ANALYZE failures;
