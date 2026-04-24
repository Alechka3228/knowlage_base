-- 1. ОЧИСТКА БАЗЫ ДАННЫХ (Полный сброс перед созданием)

DROP TABLE IF EXISTS will_item CASCADE;
DROP TABLE IF EXISTS will CASCADE;
DROP TABLE IF EXISTS ownership CASCADE;
DROP TABLE IF EXISTS property CASCADE;
DROP TABLE IF EXISTS marriage CASCADE;
DROP TABLE IF EXISTS person CASCADE;

DROP TYPE IF EXISTS ownership_type CASCADE;
DROP TYPE IF EXISTS restriction_type CASCADE;
DROP TYPE IF EXISTS property_category CASCADE;
DROP TYPE IF EXISTS gender_type CASCADE;

-- 2. ТИПЫ ДАННЫХ (Только необходимое)

CREATE TYPE gender_type AS ENUM ('M', 'F');

CREATE TYPE property_category AS ENUM (
    'movable',    -- Движимое
    'immovable',  -- Недвижимое (пентхаусы, квартиры)
    'rights',     -- Права (авторские, акции)
    'pension'     -- Пенсии и выплаты
);

CREATE TYPE restriction_type AS ENUM (
    'none',         -- Обычное имущество
    'spouse_only',  -- Только супругу (Военные пенсии по потере кормильца)
    'minors_only'   -- Только несовершеннолетним
);

CREATE TYPE ownership_type AS ENUM (
    'individual',     -- Личное (ст. 36 СК РФ - до брака, в дар, по наследству)
    'shared',         -- Долевая (выделенные проценты)
    'joint_marriage'  -- Совместная супружеская (ст. 34 СК РФ - по умолчанию 50/50 без выделения)
);

-- 3. ТАБЛИЦЫ
-- ЛЮДИ (Наследодатели и наследники)

CREATE TABLE person (
    id SERIAL PRIMARY KEY,
    last_name VARCHAR(128) NOT NULL,
    first_name VARCHAR(128) NOT NULL,
    middle_name VARCHAR(128),
    
    gender gender_type NOT NULL,
    birth_date DATE NOT NULL, -- Обязательно для расчета "обязательной доли" несовершеннолетних (ст. 1149 ГК РФ)
    death_date DATE, -- Момент открытия наследства (ст. 1113 ГК РФ)
    
    -- Дерево: ссылки на родителей для очередей по закону (гл. 63 ГК РФ)
    mother_id INTEGER REFERENCES person(id) ON DELETE SET NULL,
    father_id INTEGER REFERENCES person(id) ON DELETE SET NULL,
    
    is_unworthy BOOLEAN DEFAULT FALSE -- Недостойные наследники (ст. 1117 ГК РФ)
);

-- БРАКИ

CREATE TABLE marriage (
    id SERIAL PRIMARY KEY,
    husband_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    wife_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    
    start_date DATE NOT NULL,
    end_date DATE, -- Если NULL, то вдова/вдовец - наследник 1-й очереди (ст. 1142 ГК РФ)
    
    CHECK (husband_id != wife_id)
);

-- ИМУЩЕСТВО

CREATE TABLE property (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category property_category NOT NULL,
    
    value NUMERIC(15, 2), -- Стоимость критична для расчета "обязательной доли" и госпошлины
    restriction restriction_type DEFAULT 'none' -- Флаг для военных пенсий
);

-- ПРАВА СОБСТВЕННОСТИ (Связка людей и имущества)

CREATE TABLE ownership (
    id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL REFERENCES property(id) ON DELETE CASCADE,
    person_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    
    type ownership_type NOT NULL,
    
    -- Доля владения в процентах (до 100.00%). Имеет смысл при type = 'shared'
    share_percent NUMERIC(5, 2) DEFAULT 100.00 
        CHECK (share_percent > 0 AND share_percent <= 100),
    
    -- Привязка к браку для совместно нажитого (ст. 1150 ГК РФ)
    marriage_id INTEGER REFERENCES marriage(id) ON DELETE SET NULL,
    
    UNIQUE (property_id, person_id)
);

-- ЗАВЕЩАНИЯ (ст. 1118 ГК РФ)

CREATE TABLE will (
    id SERIAL PRIMARY KEY,
    testator_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    
    notary_date DATE NOT NULL,
    is_revoked BOOLEAN DEFAULT FALSE, -- Отмена или изменение завещания (ст. 1130 ГК РФ)
    
    UNIQUE (testator_id, notary_date)
);

-- ПУНКТЫ ЗАВЕЩАНИЯ

CREATE TABLE will_item (
    id SERIAL PRIMARY KEY,
    will_id INTEGER NOT NULL REFERENCES will(id) ON DELETE CASCADE,
    beneficiary_id INTEGER NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    
    -- Что завещаем? Если NULL - то речь идет обо всем имуществе в целом
    property_id INTEGER REFERENCES property(id) ON DELETE SET NULL,
    
    -- Какую долю (в процентах) передаем наследнику 
    share_percent NUMERIC(5, 2) DEFAULT 100.00 
        CHECK (share_percent > 0 AND share_percent <= 100)
);BEGIN;

-- ТРИГГЕР: РАЗВОД – раздел совместно нажитого имущества поровну

CREATE OR REPLACE FUNCTION after_divorce() RETURNS trigger AS $$
BEGIN
    IF NEW.end_date IS NOT NULL AND OLD.end_date IS NULL THEN
        -- Переводим совместное имущество этого брака в долевую собственность
        UPDATE ownership o
        SET type = 'shared',
            share_percent = 50.00,
            marriage_id   = NULL
        WHERE o.marriage_id = NEW.id
          AND o.type = 'joint_marriage';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER after_divorce
AFTER UPDATE OF end_date ON marriage
FOR EACH ROW EXECUTE PROCEDURE after_divorce();

-- ТРИГГЕР: ПРОВЕРКА ПОЛА В БРАКЕ В РАМКАХ ПОЛИТИКИ УЛУЧШЕНИЯ НАЦИОНАЛЬНОЙ ДЕМОГРАФИИ

CREATE OR REPLACE FUNCTION check_marriage_genders()
RETURNS trigger AS $$
DECLARE
    v_husband_gender gender_type;
    v_wife_gender    gender_type;
BEGIN
    SELECT gender INTO STRICT v_husband_gender
    FROM person WHERE id = NEW.husband_id;
    
    SELECT gender INTO STRICT v_wife_gender
    FROM person WHERE id = NEW.wife_id;

    IF v_husband_gender != 'M' THEN
        RAISE EXCEPTION 'Муж (person_id=%) должен быть мужского пола, а указан %',
            NEW.husband_id, v_husband_gender;
    END IF;

    IF v_wife_gender != 'F' THEN
        RAISE EXCEPTION 'Жена (person_id=%) должна быть женского пола, а указан %',
        NEW.wife_id, v_wife_gender;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_marriage_genders
BEFORE INSERT OR UPDATE OF husband_id, wife_id ON marriage
FOR EACH ROW EXECUTE PROCEDURE check_marriage_genders();

END;

-- ТЕСТ ТРИГГЕРА РАЗВОДА

INSERT INTO person (id, last_name, first_name, gender, birth_date) VALUES
(10, 'Петров', 'Алексей', 'M', '1975-01-01'),
(11, 'Петрова', 'Ольга', 'F', '1977-05-05');
INSERT INTO marriage (id, husband_id, wife_id, start_date) VALUES (2, 10, 11, '2000-01-01');
INSERT INTO property (id, name, category, value) VALUES (105, 'Дача', 'immovable', 2000000);
INSERT INTO ownership (id, property_id, person_id, type, share_percent, marriage_id) VALUES
(301, 105, 10, 'joint_marriage', 100.00, 2),
(302, 105, 11, 'joint_marriage', 100.00, 2);

BEGIN;
-- До развода
SELECT person_id, type, share_percent FROM ownership WHERE property_id = 105;
-- person_id=10: joint_marriage, 100; person_id=11: joint_marriage, 100.

-- Расторгаем брак
UPDATE marriage SET end_date = '2024-06-01' WHERE id = 2;

-- После развода становится равной долевой собственностью
SELECT person_id, type, share_percent FROM ownership WHERE property_id = 105;
-- person_id=10: shared, 50.00; person_id=11: shared, 50.00.
ROLLBACK;

-- ТЕСТ ТРИГГЕРА ПРОВЕРКИ ПОЛА

INSERT INTO person (id, last_name, first_name, gender, birth_date) VALUES
(20, 'Петров', 'Алексей', 'M', '1990-01-15'),
(21, 'Иванова', 'Ольга', 'F', '1992-03-10'),
(22, 'Смирнов', 'Олег', 'M', '1985-12-01');

BEGIN; -- Успешная вставка (мужчина + женщина)
INSERT INTO marriage (id, husband_id, wife_id, start_date) VALUES (100, 20, 21, '2020-06-01');
ROLLBACK;

-- Ситуация: мужчина на месте жены. Расскоментируйте, чтобы вызвать ошибку
-- BEGIN;
-- INSERT INTO marriage (id, husband_id, wife_id, start_date) VALUES (101, 20, 22, '2021-01-01');
-- ROLLBACK;

-- Ситуация: женщина на месте мужа. Расскоментируйте, чтобы вызвать ошибку
-- BEGIN;
-- INSERT INTO marriage (id, husband_id, wife_id, start_date) VALUES (102, 21, 20, '2022-02-02');
-- ROLLBACK;
