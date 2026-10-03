-- Step 9: Build a machine KPI view from small, separately readable summaries.
-- Run 04 and 05 first: they create v_machine_mtbf and v_machine_maintenance.
CREATE OR REPLACE VIEW v_machine_failure_counts AS
SELECT machine_id, COUNT(*) AS n_failures FROM failures GROUP BY machine_id;

CREATE OR REPLACE VIEW v_machine_errors AS
SELECT m.machine_id,
    ROUND(1.0 * COUNT(e.datetime) / NULLIF(
        (SELECT EXTRACT(EPOCH FROM (MAX(datetime) - MIN(datetime))) / 86400.0 FROM telemetry), 0), 4)
        AS errors_per_day
FROM machines AS m
LEFT JOIN errors AS e ON e.machine_id = m.machine_id
    AND e.datetime BETWEEN (SELECT MIN(datetime) FROM telemetry) AND (SELECT MAX(datetime) FROM telemetry)
GROUP BY m.machine_id;

CREATE OR REPLACE VIEW v_machine_kpi AS
SELECT m.machine_id, m.model, m.age,
    COALESCE(f.n_failures, 0) AS n_failures, mt.mtbf_hours,
    x.reactive_ratio, e.errors_per_day,
    ROUND(COALESCE(f.n_failures, 0) + 10 * COALESCE(x.reactive_ratio, 0)
        + 10 * COALESCE(e.errors_per_day, 0), 2) AS priority_score
FROM machines AS m
LEFT JOIN v_machine_failure_counts AS f ON f.machine_id = m.machine_id
LEFT JOIN v_machine_mtbf AS mt ON mt.machine_id = m.machine_id
LEFT JOIN v_machine_maintenance AS x ON x.machine_id = m.machine_id
LEFT JOIN v_machine_errors AS e ON e.machine_id = m.machine_id;

-- Score weights and cutoffs are illustrative, not fitted or validated thresholds.
-- Scores use displayed rounded rates. NULL MTBF means no complete observed interval.
SELECT machine_id, model, age, n_failures, mtbf_hours, reactive_ratio,
    errors_per_day, priority_score,
    CASE WHEN priority_score >= 15 THEN 'high'
         WHEN priority_score >= 10 THEN 'medium'
         ELSE 'low' END AS maintenance_priority
FROM v_machine_kpi ORDER BY priority_score DESC, machine_id;

-- One row per machine; no count multiplication from joining source events together.
SELECT COUNT(*) AS machines_in_view, SUM(n_failures) AS view_failure_sum,
    (SELECT COUNT(*) FROM failures) AS source_failure_count
FROM v_machine_kpi;
