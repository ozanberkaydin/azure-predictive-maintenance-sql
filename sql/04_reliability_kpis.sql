-- Step 5: Reliability. MTBF is the mean of complete observed failure intervals.
-- Simultaneous component failures are one machine event, avoiding zero intervals.
CREATE OR REPLACE VIEW v_failure_events AS
SELECT DISTINCT machine_id, datetime FROM failures;

-- A correlated MAX finds the nearest strictly earlier machine failure.
CREATE OR REPLACE VIEW v_failure_intervals AS
SELECT
    current_event.machine_id,
    current_event.datetime,
    (SELECT MAX(previous_event.datetime)
     FROM v_failure_events AS previous_event
     WHERE previous_event.machine_id = current_event.machine_id
       AND previous_event.datetime < current_event.datetime) AS previous_failure_ts
FROM v_failure_events AS current_event;

CREATE OR REPLACE VIEW v_machine_mtbf AS
SELECT
    machine_id,
    COUNT(*) AS complete_intervals,
    ROUND(AVG(EXTRACT(EPOCH FROM (datetime - previous_failure_ts)) / 3600.0), 2) AS mtbf_hours
FROM v_failure_intervals
WHERE previous_failure_ts IS NOT NULL
GROUP BY machine_id;

SELECT machine_id, complete_intervals, mtbf_hours FROM v_machine_mtbf ORDER BY machine_id;

-- Component MTBF uses the same idea, matching both machine and component.
WITH previous_failures AS (
    SELECT f.machine_id, f.component, f.datetime,
        (SELECT MAX(p.datetime) FROM failures AS p
         WHERE p.machine_id = f.machine_id AND p.component = f.component
           AND p.datetime < f.datetime) AS previous_failure_ts
    FROM failures AS f
)
SELECT machine_id, component, COUNT(*) AS complete_intervals,
    ROUND(AVG(EXTRACT(EPOCH FROM (datetime - previous_failure_ts)) / 3600.0), 2) AS mtbf_hours
FROM previous_failures
WHERE previous_failure_ts IS NOT NULL
GROUP BY machine_id, component
ORDER BY machine_id, component;

-- Machines without a failure in the inclusive telemetry window.
SELECT m.machine_id, m.model, m.age
FROM machines AS m
LEFT JOIN failures AS f ON f.machine_id = m.machine_id
    AND f.datetime BETWEEN (SELECT MIN(datetime) FROM telemetry) AND (SELECT MAX(datetime) FROM telemetry)
WHERE f.machine_id IS NULL
ORDER BY m.machine_id;

SELECT CAST(DATE_TRUNC('month', f.datetime) AS DATE) AS month_start,
    m.model, COUNT(*) AS failure_count
FROM failures AS f
JOIN machines AS m ON m.machine_id = f.machine_id
GROUP BY CAST(DATE_TRUNC('month', f.datetime) AS DATE), m.model
ORDER BY month_start, m.model;

-- NULL for machines with no observed failure; first intervals do not enter MTBF.
SELECT m.machine_id, m.model, MIN(f.datetime) AS first_failure_ts,
    ROUND(EXTRACT(EPOCH FROM (MIN(f.datetime) - (SELECT MIN(datetime) FROM telemetry))) / 3600.0, 2)
        AS hours_to_first_failure
FROM machines AS m
LEFT JOIN failures AS f ON f.machine_id = m.machine_id
    AND f.datetime BETWEEN (SELECT MIN(datetime) FROM telemetry) AND (SELECT MAX(datetime) FROM telemetry)
GROUP BY m.machine_id, m.model
ORDER BY m.machine_id;
