-- Удаление таблиц (в порядке, обратном зависимостям)
DROP TABLE IF EXISTS will_entries;
DROP TABLE IF EXISTS wills;
DROP TABLE IF EXISTS properties;
DROP TABLE IF EXISTS relations;
DROP TABLE IF EXISTS people;
DROP TABLE IF EXISTS relation_types;
DROP TABLE IF EXISTS countries;

-- Таблица стран
CREATE TABLE countries
(
  id   serial PRIMARY KEY,
  name character varying(32) NOT NULL UNIQUE
);

-- Таблица людей
CREATE TABLE people
(
  id          serial PRIMARY KEY,
  surname     character varying(32) NOT NULL,
  name        character varying(32) NOT NULL,
  fathers_name character varying(32),
  citizenship integer NOT NULL
  CONSTRAINT fk_people_citizenship
  REFERENCES countries (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION
);

-- Таблица типов родственных отношений
CREATE TABLE relation_types
(
  id                serial PRIMARY KEY,
  relation_type     character varying(64) NOT NULL UNIQUE,
  relation_priority integer NOT NULL
  CONSTRAINT chk_relation_priority_positive CHECK (relation_priority > 0)
);

-- Таблица родственных связей
CREATE TABLE relations
(
  person_id        integer NOT NULL,
  relative_id      integer NOT NULL,
  relation_type_id integer NOT NULL,
  PRIMARY KEY (person_id, relative_id),
  CONSTRAINT fk_relations_person
  FOREIGN KEY (person_id)
  REFERENCES people (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  CONSTRAINT fk_relations_relative
  FOREIGN KEY (relative_id)
  REFERENCES people (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  CONSTRAINT fk_relations_type
  FOREIGN KEY (relation_type_id)
  REFERENCES relation_types (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  CONSTRAINT chk_relations_not_self
  CHECK (person_id <> relative_id)
);

-- Таблица имущества
CREATE TABLE properties
(
  id        serial PRIMARY KEY,
  person_id integer NOT NULL
  CONSTRAINT fk_properties_person
  REFERENCES people (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  property  character varying(64) NOT NULL,
  movable   boolean NOT NULL DEFAULT false
);

-- Таблица завещаний
CREATE TABLE wills
(
  id          serial PRIMARY KEY,
  person_id   integer NOT NULL
  CONSTRAINT fk_wills_person
  REFERENCES people (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  description character varying(4096)
);

-- Таблица пунктов завещания
CREATE TABLE will_entries
(
  id          serial PRIMARY KEY,
  will_id     integer NOT NULL
  CONSTRAINT fk_will_entries_will
  REFERENCES wills (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  heir_id     integer
  CONSTRAINT fk_will_entries_heir
  REFERENCES people (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  property_id integer NOT NULL
  CONSTRAINT fk_will_entries_property
  REFERENCES properties (id)
  ON UPDATE NO ACTION
  ON DELETE NO ACTION,
  description character varying(4096),
  UNIQUE (will_id, heir_id, property_id)
);
