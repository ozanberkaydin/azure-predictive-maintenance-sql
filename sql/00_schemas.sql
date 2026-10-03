-- Step 1: Create the five source tables in a dedicated project database.
-- Run 00 then 01 only when you want to rebuild the project data.
-- CASCADE removes project views that depend on these tables.
BEGIN;
DROP TABLE IF EXISTS failures CASCADE;
DROP TABLE IF EXISTS maintenance CASCADE;
DROP TABLE IF EXISTS errors CASCADE;
DROP TABLE IF EXISTS telemetry CASCADE;
DROP TABLE IF EXISTS machines CASCADE;

CREATE TABLE machines (
    machine_id INTEGER PRIMARY KEY,
    model TEXT NOT NULL CHECK (model IN ('model1', 'model2', 'model3', 'model4')),
    age SMALLINT NOT NULL CHECK (age >= 0)
);
CREATE TABLE telemetry (
    datetime TIMESTAMP NOT NULL,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id),
    volt DOUBLE PRECISION NOT NULL,
    rotate DOUBLE PRECISION NOT NULL,
    pressure DOUBLE PRECISION NOT NULL,
    vibration DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (machine_id, datetime)
);
CREATE TABLE errors (
    datetime TIMESTAMP NOT NULL,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id),
    error_id TEXT NOT NULL CHECK (error_id IN ('error1', 'error2', 'error3', 'error4', 'error5')),
    PRIMARY KEY (machine_id, datetime, error_id)
);
CREATE TABLE maintenance (
    datetime TIMESTAMP NOT NULL,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id),
    component TEXT NOT NULL CHECK (component IN ('comp1', 'comp2', 'comp3', 'comp4')),
    PRIMARY KEY (machine_id, datetime, component)
);
CREATE TABLE failures (
    datetime TIMESTAMP NOT NULL,
    machine_id INTEGER NOT NULL REFERENCES machines(machine_id),
    component TEXT NOT NULL CHECK (component IN ('comp1', 'comp2', 'comp3', 'comp4')),
    PRIMARY KEY (machine_id, datetime, component)
);
COMMIT;
