-- Step 8: Daily sensor means and percentage changes before failure.
-- Percentage change replaces standardized scores to keep the calculation accessible.
CREATE OR REPLACE VIEW v_daily_telemetry AS
SELECT machine_id, CAST(datetime AS DATE) AS day_start,
    ROUND(CAST(AVG(volt) AS NUMERIC), 4) AS avg_volt,
    ROUND(CAST(AVG(rotate) AS NUMERIC), 4) AS avg_rotate,
    ROUND(CAST(AVG(pressure) AS NUMERIC), 4) AS avg_pressure,
    ROUND(CAST(AVG(vibration) AS NUMERIC), 4) AS avg_vibration
FROM telemetry GROUP BY machine_id, CAST(datetime AS DATE);

SELECT machine_id, day_start, avg_volt, avg_rotate, avg_pressure, avg_vibration
FROM v_daily_telemetry ORDER BY machine_id, day_start;

-- 24-hour moving average example for machine 1, using a time-range self join.
-- The first 23 readings have shorter history; readings_in_window makes this visible.
SELECT current_reading.machine_id, current_reading.datetime,
    COUNT(history.datetime) AS readings_in_window,
    ROUND(CAST(AVG(history.volt) AS NUMERIC), 4) AS volt_rolling_24h,
    ROUND(CAST(AVG(history.rotate) AS NUMERIC), 4) AS rotate_rolling_24h,
    ROUND(CAST(AVG(history.pressure) AS NUMERIC), 4) AS pressure_rolling_24h,
    ROUND(CAST(AVG(history.vibration) AS NUMERIC), 4) AS vibration_rolling_24h
FROM telemetry AS current_reading
JOIN telemetry AS history ON history.machine_id = current_reading.machine_id
    AND history.datetime > current_reading.datetime - INTERVAL '24 hours'
    AND history.datetime <= current_reading.datetime
WHERE current_reading.machine_id = 1
GROUP BY current_reading.machine_id, current_reading.datetime
ORDER BY current_reading.datetime;

CREATE OR REPLACE VIEW v_machine_sensor_means AS
SELECT machine_id, AVG(volt) AS mean_volt, AVG(rotate) AS mean_rotate,
    AVG(pressure) AS mean_pressure, AVG(vibration) AS mean_vibration
FROM telemetry GROUP BY machine_id;

CREATE OR REPLACE VIEW v_pre_failure_telemetry AS
SELECT f.machine_id, f.datetime AS failure_ts, f.component,
    COUNT(t.datetime) AS readings_in_window,
    AVG(t.volt) AS avg_volt, AVG(t.rotate) AS avg_rotate,
    AVG(t.pressure) AS avg_pressure, AVG(t.vibration) AS avg_vibration
FROM failures AS f
JOIN telemetry AS t ON t.machine_id = f.machine_id
    AND t.datetime >= f.datetime - INTERVAL '24 hours' AND t.datetime < f.datetime
GROUP BY f.machine_id, f.datetime, f.component;

-- (pre-failure mean - machine full-period mean) / machine mean * 100.
-- Full-period means are retrospective descriptive baselines, not forecasting features.
CREATE OR REPLACE VIEW v_sensor_changes AS
SELECT p.component, COUNT(*) AS failures_with_telemetry,
    ROUND(CAST(AVG(100.0 * (p.avg_volt - m.mean_volt) / NULLIF(m.mean_volt, 0)) AS NUMERIC), 2) AS volt_change_pct,
    ROUND(CAST(AVG(100.0 * (p.avg_rotate - m.mean_rotate) / NULLIF(m.mean_rotate, 0)) AS NUMERIC), 2) AS rotate_change_pct,
    ROUND(CAST(AVG(100.0 * (p.avg_pressure - m.mean_pressure) / NULLIF(m.mean_pressure, 0)) AS NUMERIC), 2) AS pressure_change_pct,
    ROUND(CAST(AVG(100.0 * (p.avg_vibration - m.mean_vibration) / NULLIF(m.mean_vibration, 0)) AS NUMERIC), 2) AS vibration_change_pct
FROM v_pre_failure_telemetry AS p
JOIN v_machine_sensor_means AS m ON m.machine_id = p.machine_id
GROUP BY p.component;

SELECT component, failures_with_telemetry, volt_change_pct, rotate_change_pct,
    pressure_change_pct, vibration_change_pct
FROM v_sensor_changes ORDER BY component;
