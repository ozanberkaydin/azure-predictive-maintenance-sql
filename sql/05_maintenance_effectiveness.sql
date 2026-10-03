-- Step 6: Maintenance. Reactive means matching machine, component AND timestamp.
-- Historical maintenance is retained for age lookups, excluded from in-window ratios.
CREATE OR REPLACE VIEW v_maintenance_classified AS
SELECT x.machine_id, x.datetime, x.component,
    CASE WHEN f.machine_id IS NOT NULL THEN 'reactive' ELSE 'proactive' END AS maintenance_type
FROM maintenance AS x
LEFT JOIN failures AS f ON f.machine_id = x.machine_id
    AND f.datetime = x.datetime AND f.component = x.component;

CREATE OR REPLACE VIEW v_machine_maintenance AS
SELECT machine_id, COUNT(*) AS maintenance_count,
    COUNT(CASE WHEN maintenance_type = 'reactive' THEN 1 END) AS reactive_count,
    ROUND(1.0 * COUNT(CASE WHEN maintenance_type = 'reactive' THEN 1 END)
        / NULLIF(COUNT(*), 0), 4) AS reactive_ratio
FROM v_maintenance_classified
WHERE datetime BETWEEN (SELECT MIN(datetime) FROM telemetry) AND (SELECT MAX(datetime) FROM telemetry)
GROUP BY machine_id;

SELECT m.model, SUM(x.maintenance_count) AS maintenance_count,
    SUM(x.reactive_count) AS reactive_count,
    ROUND(1.0 * SUM(x.reactive_count) / NULLIF(SUM(x.maintenance_count), 0), 4) AS reactive_ratio
FROM v_machine_maintenance AS x
JOIN machines AS m ON m.machine_id = x.machine_id
GROUP BY m.model ORDER BY m.model;

-- MAX chooses the latest replacement strictly BEFORE failure.
-- A replacement at the failure timestamp is the reactive action, not prior age.
CREATE OR REPLACE VIEW v_previous_changes AS
SELECT f.machine_id, f.datetime AS failure_ts, f.component,
    (SELECT MAX(x.datetime) FROM maintenance AS x
     WHERE x.machine_id = f.machine_id AND x.component = f.component
       AND x.datetime < f.datetime) AS previous_change_ts
FROM failures AS f;

CREATE OR REPLACE VIEW v_component_ages AS
SELECT p.machine_id, p.failure_ts, p.component, p.previous_change_ts,
    x.maintenance_type AS previous_change_type,
    EXTRACT(EPOCH FROM (p.failure_ts - p.previous_change_ts)) / 86400.0 AS component_age_days
FROM v_previous_changes AS p
LEFT JOIN v_maintenance_classified AS x ON x.machine_id = p.machine_id
    AND x.component = p.component AND x.datetime = p.previous_change_ts;

SELECT machine_id, failure_ts, component, previous_change_ts, previous_change_type,
    ROUND(component_age_days, 2) AS component_age_days
FROM v_component_ages ORDER BY machine_id, failure_ts, component;

-- Observed age since the latest replacement, grouped by that replacement type.
-- Includes only failures with known prior replacement; this is not a survival estimate.
SELECT previous_change_type, COUNT(*) AS observed_failures,
    ROUND(AVG(component_age_days), 2) AS average_days_to_failure
FROM v_component_ages
WHERE previous_change_ts IS NOT NULL
GROUP BY previous_change_type ORDER BY previous_change_type;
