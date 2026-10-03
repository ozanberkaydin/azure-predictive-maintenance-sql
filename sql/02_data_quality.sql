-- Manufacturing Predictive Maintenance SQL Project
-- Step 3: Data Quality Checks (PostgreSQL)
--
-- In this file we will check:
-- 1. NULL values
-- 2. Duplicate rows
-- 3. Duplicate logical keys
-- 4. Timestamp coverage
-- 5. Missing telemetry periods
-- 6. Orphan machine IDs
-- 7. Sensor value ranges

-- NULL counts using CASE; constraints prevent new NULL values.
SELECT
    COUNT(CASE WHEN machine_id IS NULL THEN 1 END) AS machine_id_nulls,
    COUNT(CASE WHEN model IS NULL THEN 1 END) AS model_nulls,
    COUNT(CASE WHEN age IS NULL THEN 1 END) AS age_nulls
FROM machines;

SELECT
    COUNT(CASE WHEN datetime IS NULL THEN 1 END) AS datetime_nulls,
    COUNT(CASE WHEN machine_id IS NULL THEN 1 END) AS machine_id_nulls,
    COUNT(CASE WHEN volt IS NULL THEN 1 END) AS volt_nulls,
    COUNT(CASE WHEN rotate IS NULL THEN 1 END) AS rotate_nulls,
    COUNT(CASE WHEN pressure IS NULL THEN 1 END) AS pressure_nulls,
    COUNT(CASE WHEN vibration IS NULL THEN 1 END) AS vibration_nulls
FROM telemetry;

SELECT
    COUNT(CASE WHEN datetime IS NULL THEN 1 END) AS datetime_nulls,
    COUNT(CASE WHEN machine_id IS NULL THEN 1 END) AS machine_id_nulls,
    COUNT(CASE WHEN error_id IS NULL THEN 1 END) AS error_id_nulls
FROM errors;

SELECT
    COUNT(CASE WHEN datetime IS NULL THEN 1 END) AS datetime_nulls,
    COUNT(CASE WHEN machine_id IS NULL THEN 1 END) AS machine_id_nulls,
    COUNT(CASE WHEN component IS NULL THEN 1 END) AS component_nulls
FROM maintenance;

SELECT
    COUNT(CASE WHEN datetime IS NULL THEN 1 END) AS datetime_nulls,
    COUNT(CASE WHEN machine_id IS NULL THEN 1 END) AS machine_id_nulls,
    COUNT(CASE WHEN component IS NULL THEN 1 END) AS component_nulls
FROM failures;

-- Duplicate Control (full row)
SELECT
    machine_id,
    age,
    model,
    COUNT(*) AS duplicate_count
FROM machines
GROUP BY machine_id, age, model
HAVING COUNT(*) > 1;

SELECT
    datetime,
    machine_id,
    volt,
    rotate,
    pressure,
    vibration,
    COUNT(*) AS duplicate_count
FROM telemetry
GROUP BY datetime, machine_id, volt, rotate, pressure, vibration
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    error_id,
    COUNT(*) AS duplicate_count
FROM errors
GROUP BY machine_id, datetime, error_id
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    component,
    COUNT(*) AS duplicate_count
FROM maintenance
GROUP BY machine_id, datetime, component
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    component,
    COUNT(*) AS duplicate_count
FROM failures
GROUP BY machine_id, datetime, component
HAVING COUNT(*) > 1;

-- Logical Key Duplicate
SELECT
    machine_id,
    COUNT(*) AS duplicate_count
FROM machines
GROUP BY machine_id
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    COUNT(*) AS duplicate_count
FROM telemetry
GROUP BY machine_id, datetime
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    error_id,
    COUNT(*) AS duplicate_count
FROM errors
GROUP BY machine_id, datetime, error_id
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    component,
    COUNT(*) AS duplicate_count
FROM maintenance
GROUP BY machine_id, datetime, component
HAVING COUNT(*) > 1;

SELECT
    machine_id,
    datetime,
    component,
    COUNT(*) AS duplicate_count
FROM failures
GROUP BY machine_id, datetime, component
HAVING COUNT(*) > 1;

-- Timestamp Coverage
SELECT
    'telemetry' AS table_name,
    MIN(datetime) AS min_datetime,
    MAX(datetime) AS max_datetime
FROM telemetry
UNION ALL
SELECT 'errors', MIN(datetime), MAX(datetime) FROM errors
UNION ALL
SELECT 'maintenance', MIN(datetime), MAX(datetime) FROM maintenance
UNION ALL
SELECT 'failures', MIN(datetime), MAX(datetime) FROM failures
ORDER BY table_name;

-- Events before / after the telemetry window
SELECT COUNT(*) AS maintenance_before_telemetry
FROM maintenance
WHERE datetime < (SELECT MIN(datetime) FROM telemetry);
-- 400 maintenance records occur before the telemetry observation window.
-- These are retained because they may provide useful maintenance history.

SELECT COUNT(*) AS errors_before_telemetry
FROM errors
WHERE datetime < (SELECT MIN(datetime) FROM telemetry);

SELECT COUNT(*) AS failures_before_telemetry
FROM failures
WHERE datetime < (SELECT MIN(datetime) FROM telemetry);

SELECT COUNT(*) AS maintenance_after_telemetry
FROM maintenance
WHERE datetime > (SELECT MAX(datetime) FROM telemetry);

SELECT COUNT(*) AS errors_after_telemetry
FROM errors
WHERE datetime > (SELECT MAX(datetime) FROM telemetry);

SELECT COUNT(*) AS failures_after_telemetry
FROM failures
WHERE datetime > (SELECT MAX(datetime) FROM telemetry);

-- Orphan Machine ID Checks
SELECT
    e.datetime,
    e.machine_id,
    e.error_id
FROM errors AS e
LEFT JOIN machines AS m
    ON e.machine_id = m.machine_id
WHERE m.machine_id IS NULL;

SELECT
    t.datetime,
    t.machine_id,
    t.volt,
    t.rotate,
    t.pressure,
    t.vibration
FROM telemetry AS t
LEFT JOIN machines AS m
    ON t.machine_id = m.machine_id
WHERE m.machine_id IS NULL;

SELECT
    x.machine_id,
    x.datetime,
    x.component
FROM maintenance AS x
LEFT JOIN machines AS m
    ON x.machine_id = m.machine_id
WHERE m.machine_id IS NULL;

SELECT
    f.machine_id,
    f.datetime,
    f.component
FROM failures AS f
LEFT JOIN machines AS m
    ON f.machine_id = m.machine_id
WHERE m.machine_id IS NULL;

-- Telemetry Coverage Checks
SELECT
    machine_id,
    COUNT(*) AS telemetry_rows
FROM telemetry
GROUP BY machine_id
ORDER BY machine_id;

-- Hourly completeness: compare each machine with the inclusive fleet bounds.
-- This count check assumes timestamps lie on the hourly grid; verify alignment below.
WITH bounds AS (
    SELECT MIN(datetime) AS min_ts, MAX(datetime) AS max_ts FROM telemetry
)
SELECT
    m.machine_id,
    COUNT(t.datetime) AS actual_readings,
    CAST(EXTRACT(EPOCH FROM (b.max_ts - b.min_ts)) / 3600 AS INTEGER) + 1 AS expected_readings,
    CAST(EXTRACT(EPOCH FROM (b.max_ts - b.min_ts)) / 3600 AS INTEGER) + 1
        - COUNT(t.datetime) AS missing_readings
FROM machines AS m
CROSS JOIN bounds AS b
LEFT JOIN telemetry AS t ON t.machine_id = m.machine_id
GROUP BY m.machine_id, b.min_ts, b.max_ts
ORDER BY m.machine_id;

-- Must return zero before interpreting missing_readings as missing hours.
SELECT COUNT(*) AS off_grid_readings
FROM telemetry
WHERE MOD(EXTRACT(EPOCH FROM (datetime - (SELECT MIN(datetime) FROM telemetry))), 3600) <> 0;

-- Sensor Range Checks
SELECT
    MAX(volt) AS max_volt,
    MIN(volt) AS min_volt,
    AVG(volt) AS avg_volt
FROM telemetry;

SELECT
    MAX(rotate) AS max_rotate,
    MIN(rotate) AS min_rotate,
    AVG(rotate) AS avg_rotate
FROM telemetry;

SELECT
    MAX(pressure) AS max_pressure,
    MIN(pressure) AS min_pressure,
    AVG(pressure) AS avg_pressure
FROM telemetry;

SELECT
    MAX(vibration) AS max_vibration,
    MIN(vibration) AS min_vibration,
    AVG(vibration) AS avg_vibration
FROM telemetry;
