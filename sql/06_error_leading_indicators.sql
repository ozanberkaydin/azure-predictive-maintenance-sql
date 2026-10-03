-- Step 7: Error patterns. Leading window is [failure - 24 hours, failure).
-- Matching component failure rows are kept separate, including simultaneous failures.
SELECT f.machine_id, f.datetime AS failure_ts, f.component,
    COUNT(CASE WHEN e.datetime >= f.datetime - INTERVAL '24 hours' THEN 1 END) AS errors_24h,
    COUNT(e.error_id) AS errors_48h
FROM failures AS f
LEFT JOIN errors AS e ON e.machine_id = f.machine_id
    AND e.datetime >= f.datetime - INTERVAL '48 hours' AND e.datetime < f.datetime
GROUP BY f.machine_id, f.datetime, f.component
ORDER BY f.machine_id, f.datetime, f.component;

SELECT COUNT(CASE WHEN e.datetime < f.datetime THEN 1 END) AS strict_leading_error_count,
    COUNT(e.error_id) AS inclusive_error_count,
    COUNT(CASE WHEN e.datetime = f.datetime THEN 1 END) AS same_timestamp_difference
FROM failures AS f
LEFT JOIN errors AS e ON e.machine_id = f.machine_id
    AND e.datetime >= f.datetime - INTERVAL '24 hours' AND e.datetime <= f.datetime;

-- UNION ALL spells out the five known categories; no arrays or unnest required.
CREATE OR REPLACE VIEW v_error_types AS
SELECT 'error1' AS error_id
UNION ALL SELECT 'error2'
UNION ALL SELECT 'error3'
UNION ALL SELECT 'error4'
UNION ALL SELECT 'error5';

-- Total errors / (all machines * elapsed observation days), including zero-error machines.
CREATE OR REPLACE VIEW v_error_baseline AS
SELECT types.error_id,
    1.0 * COUNT(e.error_id) / NULLIF(
        (SELECT COUNT(*) FROM machines)
        * (SELECT EXTRACT(EPOCH FROM (MAX(datetime) - MIN(datetime))) / 86400.0 FROM telemetry), 0)
        AS errors_per_machine_day
FROM v_error_types AS types
LEFT JOIN errors AS e ON e.error_id = types.error_id
    AND e.datetime BETWEEN (SELECT MIN(datetime) FROM telemetry) AND (SELECT MAX(datetime) FROM telemetry)
GROUP BY types.error_id;

SELECT error_id, ROUND(errors_per_machine_day, 6) AS baseline_errors_per_machine_day
FROM v_error_baseline ORDER BY error_id;

-- Every failure x error type is kept even when there are zero preceding errors.
CREATE OR REPLACE VIEW v_pre_failure_errors AS
SELECT f.machine_id, f.datetime AS failure_ts, f.component, types.error_id,
    COUNT(e.error_id) AS error_count_24h
FROM failures AS f
CROSS JOIN v_error_types AS types
LEFT JOIN errors AS e ON e.machine_id = f.machine_id AND e.error_id = types.error_id
    AND e.datetime >= f.datetime - INTERVAL '24 hours' AND e.datetime < f.datetime
GROUP BY f.machine_id, f.datetime, f.component, types.error_id;

CREATE OR REPLACE VIEW v_error_lift AS
SELECT p.component, p.error_id,
    ROUND(AVG(p.error_count_24h), 4) AS pre_failure_errors_per_day,
    ROUND(b.errors_per_machine_day, 6) AS baseline_errors_per_machine_day,
    ROUND(AVG(p.error_count_24h) / NULLIF(b.errors_per_machine_day, 0), 2) AS lift
FROM v_pre_failure_errors AS p
JOIN v_error_baseline AS b ON b.error_id = p.error_id
GROUP BY p.component, p.error_id, b.errors_per_machine_day;

SELECT component, error_id, pre_failure_errors_per_day, baseline_errors_per_machine_day, lift
FROM v_error_lift ORDER BY lift DESC, component, error_id;

-- Each failure has exactly one row per error type; error1 counts each once.
SELECT component, COUNT(CASE WHEN error_id = 'error1' THEN 1 END) AS failure_event_count,
    SUM(CASE WHEN error_id = 'error1' THEN error_count_24h ELSE 0 END) AS error1_count_24h,
    SUM(CASE WHEN error_id = 'error2' THEN error_count_24h ELSE 0 END) AS error2_count_24h,
    SUM(CASE WHEN error_id = 'error3' THEN error_count_24h ELSE 0 END) AS error3_count_24h,
    SUM(CASE WHEN error_id = 'error4' THEN error_count_24h ELSE 0 END) AS error4_count_24h,
    SUM(CASE WHEN error_id = 'error5' THEN error_count_24h ELSE 0 END) AS error5_count_24h
FROM v_pre_failure_errors GROUP BY component ORDER BY component;
