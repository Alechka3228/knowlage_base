CREATE OR REPLACE FUNCTION max_step(NUMERIC, NUMERIC)
RETURNS NUMERIC AS
$$
DECLARE
    res NUMERIC;
BEGIN
    IF $1 IS NULL THEN
        RETURN $2;
    END IF;
    IF $2 IS NULL THEN
        RETURN $1;
    END IF;
    res = $1;
    IF $1 < $2 THEN
        res = $2;
    END IF;
    RETURN res; 
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION min_step(NUMERIC, NUMERIC)
RETURNS NUMERIC AS
$$
DECLARE
    res NUMERIC;
BEGIN
    IF $1 IS NULL THEN
        RETURN $2;
    END IF;
    IF $2 IS NULL THEN
        RETURN $1;
    END IF;
    res = $1;
    IF $1 > $2 THEN
        res = $2;
    END IF;
    RETURN res; 
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION avg_step(NUMERIC[], NUMERIC)
RETURNS NUMERIC[] AS
$$
DECLARE
    res NUMERIC[];
BEGIN
    res[1] = $1[1] + $2;
    res[2] = $1[2] + 1;
    RETURN res; 
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION avg_final_step(NUMERIC[])
RETURNS NUMERIC AS
$$
DECLARE
    res NUMERIC;
BEGIN
    res = 0;
    IF $1[2] = 0 THEN
        RETURN res;
    END IF;
    res = $1[1]/$1[2];
    RETURN res; 
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE AGGREGATE my_max(NUMERIC)
(
    stype = NUMERIC,
    sfunc = max_step
);

CREATE OR REPLACE AGGREGATE my_min(NUMERIC)
(
    stype = NUMERIC,
    sfunc = min_step
);

CREATE OR REPLACE AGGREGATE my_avg(NUMERIC)
(
    sfunc = avg_step,
    stype = NUMERIC[],
    initcond = '{0, 0}',
    finalfunc = avg_final_step
);

-- 1
CREATE OR REPLACE FUNCTION avg_age()
RETURNS NUMERIC(5,2) AS $$
    SELECT 
        my_avg(
            (
            (COALESCE(death_date, CURRENT_DATE) - birth_date)/365
            )::NUMERIC(5,2)
        )
    FROM person;
$$ LANGUAGE sql;

SELECT avg_age();

-- 2
CREATE OR REPLACE FUNCTION min_age()
RETURNS NUMERIC(5,2) AS $$
    SELECT 
        my_min(
            (
            (COALESCE(death_date, CURRENT_DATE) - birth_date)/365
            )::NUMERIC(5,2)
        )
    FROM person;
$$ LANGUAGE sql;

SELECT min_age();

-- 3
CREATE OR REPLACE FUNCTION max_age()
RETURNS NUMERIC(5,2) AS $$
    SELECT 
        my_max(
            (
            (COALESCE(death_date, CURRENT_DATE) - birth_date)/365
            )::NUMERIC(5,2)
        )
    FROM person;
$$ LANGUAGE sql;

SELECT max_age();

-- 4
CREATE OR REPLACE FUNCTION min_marriage_duration()
RETURNS NUMERIC(5,2) AS $$
    SELECT 
        my_min(
            (
            (COALESCE(end_date, CURRENT_DATE) - start_date)/365
            )::NUMERIC(5,2)
        )
    FROM marriage;
$$ LANGUAGE sql;

SELECT min_marriage_duration();

-- 5
CREATE OR REPLACE FUNCTION max_marriage_duration()
RETURNS NUMERIC(5,2) AS $$
    SELECT 
        my_max(
            (
            (COALESCE(end_date, CURRENT_DATE) - start_date)/365
            )::NUMERIC(5,2)
        )
    FROM marriage;
$$ LANGUAGE sql;

SELECT max_marriage_duration();