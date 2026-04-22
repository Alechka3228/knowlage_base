DO $$
BEGIN
    INSERT INTO people (id, surname, name, fathers_name, citizenship) VALUES (1000, 'Test', 'User', NULL, 1);
    INSERT INTO properties (id, person_id, property, movable) VALUES (1000, 1000, 'TestProp', false);
    INSERT INTO wills (id, person_id, description) VALUES (1000, 1, 'TestWill');
    INSERT INTO will_entries (will_id, heir_id, property_id) VALUES (1000, 3, 1000);
    RAISE NOTICE 'Ошибка: триггер affiliation не сработал';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Триггер affiliation: ошибка "%"', SQLERRM;
END;
$$;

SELECT 'После проверки affiliation с чужим имуществом' AS comment;
SELECT * FROM will_entries WHERE will_id = 1000;
SELECT * FROM wills WHERE id = 1000;

DO $$
BEGIN
    INSERT INTO wills (id, person_id, description) VALUES (1001, 1, 'TestWill2');
    INSERT INTO properties (id, person_id, property, movable) VALUES (1001, 1, 'TestProp2', true);
    INSERT INTO will_entries (will_id, heir_id, property_id) VALUES (1001, 3, 1001);
    RAISE NOTICE 'Триггер affiliation: корректная вставка выполнена';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка: %', SQLERRM;
END;
$$;

SELECT 'После корректной вставки will_entries' AS comment;
SELECT w.id AS will_id, w.person_id, we.heir_id, we.property_id, p.property
FROM will_entries we
JOIN wills w ON we.will_id = w.id
JOIN properties p ON we.property_id = p.id
WHERE w.id = 1001;

DO $$
DECLARE
    will_count integer;
BEGIN
    INSERT INTO wills (id, person_id, description) VALUES (1002, 2, 'TestWill3');
    INSERT INTO properties (id, person_id, property, movable) VALUES (1002, 2, 'TestProp3', false);
    INSERT INTO will_entries (will_id, heir_id, property_id) VALUES (1002, 3, 1002);
    DELETE FROM will_entries WHERE will_id = 1002;
    SELECT COUNT(*) INTO will_count FROM wills WHERE id = 1002;
    IF will_count = 0 THEN
        RAISE NOTICE 'Триггер meaninglessness: завещание удалено после удаления последнего пункта';
    ELSE
        RAISE NOTICE 'Ошибка: завещание не удалено';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка: %', SQLERRM;
END;
$$;

SELECT 'После удаления единственного пункта завещания 1002' AS comment;
SELECT * FROM wills WHERE id = 1002;
SELECT * FROM will_entries WHERE will_id = 1002;

DO $$
DECLARE
    will_count integer;
BEGIN
    INSERT INTO wills (id, person_id, description) VALUES (1003, 1, 'TestWill4');
    INSERT INTO properties (id, person_id, property, movable) VALUES (1003, 1, 'PropA', false);
    INSERT INTO properties (id, person_id, property, movable) VALUES (1004, 1, 'PropB', true);
    INSERT INTO will_entries (will_id, heir_id, property_id) VALUES (1003, 3, 1003);
    INSERT INTO will_entries (will_id, heir_id, property_id) VALUES (1003, 4, 1004);
    DELETE FROM will_entries WHERE will_id = 1003 AND property_id = 1003;
    SELECT COUNT(*) INTO will_count FROM wills WHERE id = 1003;
    IF will_count = 1 THEN
        RAISE NOTICE 'Триггер meaninglessness: завещание осталось после удаления одного пункта';
    ELSE
        RAISE NOTICE 'Ошибка: завещание удалено преждевременно';
    END IF;
    DELETE FROM will_entries WHERE will_id = 1003;
    SELECT COUNT(*) INTO will_count FROM wills WHERE id = 1003;
    IF will_count = 0 THEN
        RAISE NOTICE 'Триггер meaninglessness: завещание удалено после удаления последнего пункта (повторно)';
    ELSE
        RAISE NOTICE 'Ошибка: завещание не удалено';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Ошибка: %', SQLERRM;
END;
$$;

SELECT 'После удаления одного из двух пунктов завещания 1003' AS comment;
SELECT w.id, w.description, COUNT(we.id) as entries_count
FROM wills w
LEFT JOIN will_entries we ON w.id = we.will_id
WHERE w.id = 1003
GROUP BY w.id, w.description;

SELECT 'После удаления последнего пункта завещания 1003' AS comment;
SELECT * FROM wills WHERE id = 1003;
SELECT * FROM will_entries WHERE will_id = 1003;

DELETE FROM will_entries WHERE will_id IN (1001, 1002, 1003);
DELETE FROM wills WHERE id IN (1000, 1001, 1002, 1003);
DELETE FROM properties WHERE id IN (1000, 1001, 1002, 1003, 1004);
DELETE FROM people WHERE id = 1000;

SELECT 'Очистка тестовых данных завершена' AS status;
SELECT COUNT(*) FROM people WHERE id = 1000;
SELECT COUNT(*) FROM wills WHERE id >= 1000;
SELECT COUNT(*) FROM properties WHERE id >= 1000;
