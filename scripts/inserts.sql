INSERT INTO countries (id, name) VALUES
(1, 'Россия'),
(2, 'США'),
(3, 'Германия')
ON CONFLICT (id) DO NOTHING;

INSERT INTO relation_types (id, relation_type, relation_priority) VALUES
(1, 'супруг(а)', 1),
(2, 'родитель', 3),
(3, 'ребенок', 2),
(4, 'брат/сестра', 4)
ON CONFLICT (id) DO NOTHING;

INSERT INTO people (id, surname, name, fathers_name, citizenship) VALUES
(1, 'Иванов', 'Иван', 'Иванович', 1),
(2, 'Иванова', 'Мария', 'Петровна', 1),
(3, 'Иванов', 'Алексей', 'Иванович', 1),
(4, 'Иванова', 'Екатерина', 'Ивановна', 1),
(5, 'Иванов', 'Иван', 'Петрович', 1),
(6, 'Smith', 'John', NULL, 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO relations (person_id, relative_id, relation_type_id) VALUES
(1, 2, 1),
(1, 3, 2),
(1, 4, 2),
(2, 3, 2),
(2, 4, 2),
(5, 1, 2),
(3, 1, 3),
(3, 2, 3),
(4, 1, 3),
(4, 2, 3),
(1, 5, 3),
(3, 4, 4),
(4, 3, 4)
ON CONFLICT (person_id, relative_id) DO NOTHING;

INSERT INTO properties (id, person_id, property, movable) VALUES
(1, 1, 'Квартира (3-комнатная, Москва)', false),
(2, 1, 'Автомобиль Toyota Camry', true),
(3, 2, 'Дача (6 соток, Подмосковье)', false),
(4, 3, 'Ноутбук Apple MacBook Pro', true),
(5, 5, 'Гараж (металлический)', false),
(6, 1, 'Денежный вклад (2 млн руб.)', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO wills (id, person_id, description) VALUES
(1, 1, 'Завещание Ивана Ивановича: распределить всё имущество между детьми.'),
(2, 2, 'Завещание Марии Петровны: передача дачи и части денег сыну Алексею.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO will_entries (id, will_id, heir_id, property_id, description) VALUES
(1, 1, 3, 1, 'Квартира переходит сыну Алексею'),
(2, 1, 4, 2, 'Автомобиль переходит дочери Екатерине'),
(3, 1, 4, 6, 'Денежный вклад переходит дочери Екатерине'),
(4, 2, 3, 3, 'Дача переходит сыну Алексею'),
(5, 2, 3, 6, 'Половина денежного вклада переходит сыну Алексею (по завещанию Марии)')
ON CONFLICT (will_id, heir_id, property_id) DO NOTHING;

SELECT setval('people_id_seq', COALESCE((SELECT MAX(id) FROM people), 1));
SELECT setval('relation_types_id_seq', COALESCE((SELECT MAX(id) FROM relation_types), 1));
SELECT setval('properties_id_seq', COALESCE((SELECT MAX(id) FROM properties), 1));
SELECT setval('wills_id_seq', COALESCE((SELECT MAX(id) FROM wills), 1));
SELECT setval('will_entries_id_seq', COALESCE((SELECT MAX(id) FROM will_entries), 1));
SELECT setval('countries_id_seq', COALESCE((SELECT MAX(id) FROM countries), 1));
