-- =====================================================
-- АГРЕГАТНЫЕ И ОКОННЫЕ ФУНКЦИИ ДЛЯ РАСЧЕТОВ
-- =====================================================

-- ---------------------------------------------------------------------
-- 1. ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ДЛЯ РАСЧЕТА ВОЗРАСТА
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION calculate_age(birth_date DATE, death_date DATE)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    end_date DATE;
    age_years NUMERIC(5,2);
BEGIN
    -- Если дата смерти не указана, считаем на текущую дату
    end_date := COALESCE(death_date, CURRENT_DATE);
    
    -- Проверка, что дата рождения не NULL и не позже даты смерти/текущей
    IF birth_date IS NULL OR birth_date > end_date THEN
        RETURN NULL;
    END IF;
    
    -- Расчет возраста с точностью до 2 знаков
    age_years := EXTRACT(YEAR FROM age(end_date, birth_date));
    age_years := age_years + 
                 (EXTRACT(MONTH FROM age(end_date, birth_date)) / 12.0) + 
                 (EXTRACT(DAY FROM age(end_date, birth_date)) / 365.25);
    
    RETURN ROUND(age_years, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ---------------------------------------------------------------------
-- 2. АГРЕГАТНЫЕ ФУНКЦИИ ДЛЯ ВОЗРАСТА
-- ---------------------------------------------------------------------

-- Средний возраст по пачке людей (агрегатная функция)
CREATE OR REPLACE FUNCTION avg_age(people_cursor REFCURSOR)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    rec RECORD;
    total_age NUMERIC(15,2) := 0;
    person_count INTEGER := 0;
    current_age NUMERIC(5,2);
BEGIN
    LOOP
        FETCH people_cursor INTO rec;
        EXIT WHEN NOT FOUND;
        
        -- Вычисляем возраст для каждого человека
        current_age := calculate_age(rec.birth_date, rec.death_date);
        
        IF current_age IS NOT NULL THEN
            total_age := total_age + current_age;
            person_count := person_count + 1;
        END IF;
    END LOOP;
    
    IF person_count = 0 THEN
        RETURN NULL;
    END IF;
    
    RETURN ROUND(total_age / person_count, 2);
END;
$$ LANGUAGE plpgsql;


-- Вспомогательная функция для агрегации (вариант с массивом ID)
CREATE OR REPLACE FUNCTION avg_age_by_ids(person_ids INTEGER[])
RETURNS NUMERIC(5,2) AS $$
DECLARE
    total_age NUMERIC(15,2) := 0;
    person_count INTEGER := 0;
    p RECORD;
BEGIN
    FOR p IN 
        SELECT birth_date, death_date 
        FROM person 
        WHERE id = ANY(person_ids)
    LOOP
        total_age := total_age + calculate_age(p.birth_date, p.death_date);
        person_count := person_count + 1;
    END LOOP;
    
    IF person_count = 0 THEN
        RETURN NULL;
    END IF;
    
    RETURN ROUND(total_age / person_count, 2);
END;
$$ LANGUAGE plpgsql;


-- Минимальный возраст выбранных людей
CREATE OR REPLACE FUNCTION min_age(person_ids INTEGER[] DEFAULT NULL)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    min_age_val NUMERIC(5,2);
BEGIN
    IF person_ids IS NULL THEN
        SELECT MIN(calculate_age(birth_date, death_date))
        INTO min_age_val
        FROM person;
    ELSE
        SELECT MIN(calculate_age(birth_date, death_date))
        INTO min_age_val
        FROM person
        WHERE id = ANY(person_ids);
    END IF;
    
    RETURN min_age_val;
END;
$$ LANGUAGE plpgsql;


-- Максимальный возраст выбранных людей
CREATE OR REPLACE FUNCTION max_age(person_ids INTEGER[] DEFAULT NULL)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    max_age_val NUMERIC(5,2);
BEGIN
    IF person_ids IS NULL THEN
        SELECT MAX(calculate_age(birth_date, death_date))
        INTO max_age_val
        FROM person;
    ELSE
        SELECT MAX(calculate_age(birth_date, death_date))
        INTO max_age_val
        FROM person
        WHERE id = ANY(person_ids);
    END IF;
    
    RETURN max_age_val;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 3. АГРЕГАТНЫЕ ФУНКЦИИ ДЛЯ ПРОДОЛЖИТЕЛЬНОСТИ БРАКА
-- ---------------------------------------------------------------------

-- Вспомогательная функция для расчета продолжительности брака
CREATE OR REPLACE FUNCTION calculate_marriage_duration(start_date DATE, end_date DATE)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    actual_end_date DATE;
    duration_years NUMERIC(5,2);
BEGIN
    -- Если дата окончания не указана, считаем на текущую дату
    actual_end_date := COALESCE(end_date, CURRENT_DATE);
    
    IF start_date IS NULL OR start_date > actual_end_date THEN
        RETURN NULL;
    END IF;
    
    duration_years := EXTRACT(YEAR FROM age(actual_end_date, start_date));
    duration_years := duration_years + 
                      (EXTRACT(MONTH FROM age(actual_end_date, start_date)) / 12.0) + 
                      (EXTRACT(DAY FROM age(actual_end_date, start_date)) / 365.25);
    
    RETURN ROUND(duration_years, 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- Минимальная продолжительность брака среди выбранных
CREATE OR REPLACE FUNCTION min_marriage_duration(marriage_ids INTEGER[] DEFAULT NULL)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    min_duration NUMERIC(5,2);
BEGIN
    IF marriage_ids IS NULL THEN
        SELECT MIN(calculate_marriage_duration(start_date, end_date))
        INTO min_duration
        FROM marriage;
    ELSE
        SELECT MIN(calculate_marriage_duration(start_date, end_date))
        INTO min_duration
        FROM marriage
        WHERE id = ANY(marriage_ids);
    END IF;
    
    RETURN min_duration;
END;
$$ LANGUAGE plpgsql;


-- Максимальная продолжительность брака среди выбранных
CREATE OR REPLACE FUNCTION max_marriage_duration(marriage_ids INTEGER[] DEFAULT NULL)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    max_duration NUMERIC(5,2);
BEGIN
    IF marriage_ids IS NULL THEN
        SELECT MAX(calculate_marriage_duration(start_date, end_date))
        INTO max_duration
        FROM marriage;
    ELSE
        SELECT MAX(calculate_marriage_duration(start_date, end_date))
        INTO max_duration
        FROM marriage
        WHERE id = ANY(marriage_ids);
    END IF;
    
    RETURN max_duration;
END;
$$ LANGUAGE plpgsql;


-- ---------------------------------------------------------------------
-- 4. ОКОННЫЕ ФУНКЦИИ (WINDOW FUNCTIONS)
-- ---------------------------------------------------------------------

-- Оконная функция: возраст каждого человека с расчетом среднего по группе
SELECT 
    id,
    last_name,
    first_name,
    calculate_age(birth_date, death_date) AS age,
    AVG(calculate_age(birth_date, death_date)) OVER (PARTITION BY gender) AS avg_age_by_gender,
    AVG(calculate_age(birth_date, death_date)) OVER () AS overall_avg_age,
    RANK() OVER (ORDER BY calculate_age(birth_date, death_date) DESC NULLS LAST) AS age_rank
FROM person
WHERE death_date IS NULL OR death_date > CURRENT_DATE - INTERVAL '150 years';


-- Оконная функция: продолжительность браков с ранжированием
SELECT 
    m.id,
    p1.last_name AS husband,
    p2.last_name AS wife,
    m.start_date,
    m.end_date,
    calculate_marriage_duration(m.start_date, m.end_date) AS duration_years,
    AVG(calculate_marriage_duration(m.start_date, m.end_date)) OVER () AS avg_duration_all,
    AVG(calculate_marriage_duration(m.start_date, m.end_date)) OVER (
        PARTITION BY EXTRACT(YEAR FROM m.start_date)
    ) AS avg_duration_by_start_year,
    ROW_NUMBER() OVER (ORDER BY calculate_marriage_duration(m.start_date, m.end_date) DESC) AS duration_rank
FROM marriage m
JOIN person p1 ON m.husband_id = p1.id
JOIN person p2 ON m.wife_id = p2.id;


-- ---------------------------------------------------------------------
-- 5. ПРЕДСТАВЛЕНИЯ (VIEWS) ДЛЯ УДОБНОЙ РАБОТЫ
-- ---------------------------------------------------------------------

-- Представление с вычисленным возрастом всех людей
CREATE OR REPLACE VIEW person_age_view AS
SELECT 
    id,
    last_name,
    first_name,
    middle_name,
    gender,
    birth_date,
    death_date,
    calculate_age(birth_date, death_date) AS age,
    CASE 
        WHEN death_date IS NOT NULL THEN 'умер(ла)'
        ELSE 'жив(а)'
    END AS status
FROM person
ORDER BY calculate_age(birth_date, death_date) DESC NULLS LAST;


-- Представление с продолжительностью всех браков
CREATE OR REPLACE VIEW marriage_duration_view AS
SELECT 
    m.id,
    m.husband_id,
    h.last_name AS husband_last_name,
    h.first_name AS husband_first_name,
    m.wife_id,
    w.last_name AS wife_last_name,
    w.first_name AS wife_first_name,
    m.start_date,
    m.end_date,
    calculate_marriage_duration(m.start_date, m.end_date) AS duration_years,
    CASE 
        WHEN m.end_date IS NULL THEN 'активный'
        ELSE 'расторгнут'
    END AS status
FROM marriage m
JOIN person h ON m.husband_id = h.id
JOIN person w ON m.wife_id = w.id
ORDER BY calculate_marriage_duration(m.start_date, m.end_date) DESC NULLS LAST;


-- Представление со статистикой по возрастам (оконные функции)
CREATE OR REPLACE VIEW age_statistics AS
SELECT 
    gender,
    COUNT(*) AS total_count,
    ROUND(AVG(calculate_age(birth_date, death_date)), 2) AS avg_age,
    MIN(calculate_age(birth_date, death_date)) AS min_age,
    MAX(calculate_age(birth_date, death_date)) AS max_age,
    ROUND(STDDEV(calculate_age(birth_date, death_date)), 2) AS age_stddev,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY calculate_age(birth_date, death_date)) AS median_age
FROM person
WHERE birth_date IS NOT NULL
GROUP BY gender;


-- ---------------------------------------------------------------------
-- 6. ТЕСТИРОВАНИЕ ФУНКЦИЙ
-- ---------------------------------------------------------------------

DO $$
DECLARE
    avg_result NUMERIC(5,2);
    cur REFCURSOR;
    person_ids INTEGER[];
BEGIN
    -- Подготовка тестовых данных
    INSERT INTO person (id, last_name, first_name, gender, birth_date, death_date) VALUES
    (100, 'Тестов', 'Мужчина1', 'M', '1980-01-01', NULL),
    (101, 'Тестова', 'Женщина1', 'F', '1985-06-15', NULL),
    (102, 'Тестов', 'Мужчина2', 'M', '1975-03-20', '2020-12-31'),
    (103, 'Тестова', 'Женщина2', 'F', '1990-11-10', NULL)
    ON CONFLICT (id) DO NOTHING;
    
    -- Тест min_age
    RAISE NOTICE 'min_age всех: %', min_age(NULL);
    
    -- Тест max_age
    RAISE NOTICE 'max_age всех: %', max_age(NULL);
    
    -- Тест с конкретными ID
    person_ids := ARRAY[100, 101, 102];
    RAISE NOTICE 'min_age для ID[100,101,102]: %', min_age(person_ids);
    RAISE NOTICE 'max_age для ID[100,101,102]: %', max_age(person_ids);
    RAISE NOTICE 'avg_age для ID[100,101,102]: %', avg_age_by_ids(person_ids);
    
    -- Тест продолжительности браков
    INSERT INTO marriage (id, husband_id, wife_id, start_date, end_date) VALUES
    (200, 100, 101, '2010-06-01', NULL),
    (201, 102, 103, '2000-01-01', '2015-12-31')
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'min_marriage_duration: %', min_marriage_duration(NULL);
    RAISE NOTICE 'max_marriage_duration: %', max_marriage_duration(NULL);
    
    RAISE NOTICE 'min_marriage_duration для ID[200,201]: %', min_marriage_duration(ARRAY[200, 201]);
    RAISE NOTICE 'max_marriage_duration для ID[200,201]: %', max_marriage_duration(ARRAY[200, 201]);
    
END $$;


-- ---------------------------------------------------------------------
-- 7. ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ ОКОННЫХ ФУНКЦИЙ
-- ---------------------------------------------------------------------

-- Пример 1: Для каждого человека отобразить его возраст и разницу с максимальным возрастом
SELECT 
    id,
    last_name || ' ' || first_name AS full_name,
    calculate_age(birth_date, death_date) AS age,
    MAX(calculate_age(birth_date, death_date)) OVER () AS max_age,
    MAX(calculate_age(birth_date, death_date)) OVER () - 
        COALESCE(calculate_age(birth_date, death_date), 0) AS years_to_max
FROM person
WHERE birth_date IS NOT NULL
ORDER BY age DESC NULLS LAST;


-- Пример 2: Топ-3 самых возрастных человека в каждой половой группе
SELECT * FROM (
    SELECT 
        id,
        last_name || ' ' || first_name AS full_name,
        gender,
        calculate_age(birth_date, death_date) AS age,
        ROW_NUMBER() OVER (PARTITION BY gender ORDER BY calculate_age(birth_date, death_date) DESC) AS rn
    FROM person
    WHERE birth_date IS NOT NULL
) ranked
WHERE rn <= 3
ORDER BY gender, age DESC;


-- Пример 3: Кумулятивная статистика по бракам (накопленная сумма продолжительности)
SELECT 
    m.id,
    p1.last_name || ' & ' || p2.last_name AS couple,
    m.start_date,
    calculate_marriage_duration(m.start_date, m.end_date) AS duration,
    SUM(calculate_marriage_duration(m.start_date, m.end_date)) OVER (ORDER BY m.start_date) AS cumulative_duration,
    AVG(calculate_marriage_duration(m.start_date, m.end_date)) OVER (ORDER BY m.start_date) AS running_avg
FROM marriage m
JOIN person p1 ON m.husband_id = p1.id
JOIN person p2 ON m.wife_id = p2.id
WHERE calculate_marriage_duration(m.start_date, m.end_date) IS NOT NULL
ORDER BY m.start_date;