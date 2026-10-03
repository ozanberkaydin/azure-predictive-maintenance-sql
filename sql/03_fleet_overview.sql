-- Manufacturing Predictive Maintenance SQL Project
-- Step 4: Fleet Overview (PostgreSQL)
--
-- Goals:
-- 1. Understand fleet size and model distribution
-- 2. Analyze machine age distribution
-- 3. Compare failure burden across models
-- 4. Identify machines with the highest failure counts
-- 5. Compare component failure shares

SELECT
    model,
    COUNT(*) AS machine_count
FROM machines
GROUP BY model
ORDER BY machine_count DESC, model;

-- Machine Age Distribution
SELECT
    MAX(age) AS max_age,
    MIN(age) AS min_age,
    ROUND(AVG(age)::NUMERIC, 2) AS avg_age
FROM machines;

-- Machine Age Buckets (row-level check)
SELECT
    machine_id,
    age,
    CASE
        WHEN age BETWEEN 0 AND 5 THEN '0-5'
        WHEN age BETWEEN 6 AND 10 THEN '6-10'
        WHEN age BETWEEN 11 AND 15 THEN '11-15'
        ELSE '16+'
    END AS age_bucket
FROM machines
ORDER BY machine_id;

-- Age bucket summary
WITH age_labeled AS (
    SELECT
        machine_id,
        age,
        CASE
            WHEN age BETWEEN 0 AND 5 THEN '0-5'
            WHEN age BETWEEN 6 AND 10 THEN '6-10'
            WHEN age BETWEEN 11 AND 15 THEN '11-15'
            ELSE '16+'
        END AS age_bucket,
        CASE
            WHEN age BETWEEN 0 AND 5 THEN 1
            WHEN age BETWEEN 6 AND 10 THEN 2
            WHEN age BETWEEN 11 AND 15 THEN 3
            ELSE 4
        END AS bucket_order
    FROM machines
)
SELECT
    age_bucket,
    COUNT(*) AS machine_count,
    ROUND(AVG(age)::NUMERIC, 2) AS avg_age
FROM age_labeled
GROUP BY age_bucket, bucket_order
ORDER BY bucket_order;

-- Model x age mix
WITH age_labeled AS (
    SELECT
        model,
        age,
        CASE
            WHEN age BETWEEN 0 AND 5 THEN '0-5'
            WHEN age BETWEEN 6 AND 10 THEN '6-10'
            WHEN age BETWEEN 11 AND 15 THEN '11-15'
            ELSE '16+'
        END AS age_bucket
    FROM machines
)
SELECT
    model,
    age_bucket,
    COUNT(*) AS machine_count,
    ROUND(AVG(age)::NUMERIC, 2) AS avg_age
FROM age_labeled
GROUP BY model, age_bucket
ORDER BY model, MIN(age);

-- Failure burden by model (normalize by fleet size, not raw counts)
SELECT
    m.model,
    COUNT(DISTINCT m.machine_id) AS machine_count,
    COUNT(f.machine_id) AS failure_count,
    ROUND(
        COUNT(f.machine_id)::NUMERIC / NULLIF(COUNT(DISTINCT m.machine_id), 0),
        3
    ) AS failures_per_machine
FROM machines AS m
LEFT JOIN failures AS f
    ON f.machine_id = m.machine_id
GROUP BY m.model
ORDER BY failures_per_machine DESC, m.model;

-- Failure burden by age bucket
WITH age_labeled AS (
    SELECT
        machine_id,
        CASE
            WHEN age BETWEEN 0 AND 5 THEN '0-5'
            WHEN age BETWEEN 6 AND 10 THEN '6-10'
            WHEN age BETWEEN 11 AND 15 THEN '11-15'
            ELSE '16+'
        END AS age_bucket,
        CASE
            WHEN age BETWEEN 0 AND 5 THEN 1
            WHEN age BETWEEN 6 AND 10 THEN 2
            WHEN age BETWEEN 11 AND 15 THEN 3
            ELSE 4
        END AS bucket_order
    FROM machines
)
SELECT
    a.age_bucket,
    COUNT(DISTINCT a.machine_id) AS machine_count,
    COUNT(f.machine_id) AS failure_count,
    ROUND(
        COUNT(f.machine_id)::NUMERIC / NULLIF(COUNT(DISTINCT a.machine_id), 0),
        3
    ) AS failures_per_machine
FROM age_labeled AS a
LEFT JOIN failures AS f
    ON f.machine_id = a.machine_id
GROUP BY a.age_bucket, a.bucket_order
ORDER BY a.bucket_order;

-- Top 10 machines. Exactly ten rows; machine_id resolves equal counts.
SELECT m.machine_id, m.model, m.age, COUNT(f.machine_id) AS failure_count
FROM machines AS m
LEFT JOIN failures AS f ON f.machine_id = m.machine_id
GROUP BY m.machine_id, m.model, m.age
ORDER BY failure_count DESC, m.machine_id
LIMIT 10;

-- Component share: a simple subquery provides the total failure count.
SELECT
    component,
    COUNT(*) AS failure_count,
    ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM failures), 0), 2) AS failure_pct
FROM failures
GROUP BY component
ORDER BY failure_count DESC, component;
