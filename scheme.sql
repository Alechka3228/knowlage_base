DROP TABLE IF EXISTS public.will_entries;
DROP TABLE IF EXISTS public.wills;
DROP TABLE IF EXISTS public.properties;
DROP TABLE IF EXISTS public.relations;
DROP TABLE IF EXISTS public.people;
DROP TABLE IF EXISTS public.relation_types;
DROP TABLE IF EXISTS public.countries;

CREATE TABLE IF NOT EXISTS public.people
(
    id serial,
    surname character varying(32) NOT NULL,
    name character varying(32) NOT NULL,
    fathers_name character varying(32),
    citizenship integer NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.relations
(
    person_id integer,
    relative_id integer,
    relation_type_id integer NOT NULL,
    PRIMARY KEY (person_id, relative_id)
);

CREATE TABLE IF NOT EXISTS public.relation_types
(
    id serial,
    relation_type character varying(64) NOT NULL,
    relation_priority integer NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (relation_type)
);

CREATE TABLE IF NOT EXISTS public.properties
(
    id serial,
    person_id integer NOT NULL,
    property character varying(64) NOT NULL,
    movable boolean NOT NULL DEFAULT false,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.will_entries
(
    id serial,
    will_id integer NOT NULL,
    heir_id integer,
    property_id integer NOT NULL,
    description character varying(4096),
    PRIMARY KEY (id),
    UNIQUE (will_id, heir_id, property_id)
);

CREATE TABLE IF NOT EXISTS public.wills
(
    id serial,
    person_id integer NOT NULL,
    description character varying(4096),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.countries
(
    id serial,
    name character varying(32) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (name)
);

ALTER TABLE IF EXISTS public.people
    ADD FOREIGN KEY (citizenship)
    REFERENCES public.countries (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.relations
    ADD FOREIGN KEY (relation_type_id)
    REFERENCES public.relation_types (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.relations
    ADD FOREIGN KEY (person_id)
    REFERENCES public.people (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.relations
    ADD FOREIGN KEY (relative_id)
    REFERENCES public.people (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.properties
    ADD FOREIGN KEY (person_id)
    REFERENCES public.people (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.will_entries
    ADD FOREIGN KEY (will_id)
    REFERENCES public.wills (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.will_entries
    ADD FOREIGN KEY (heir_id)
    REFERENCES public.people (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.will_entries
    ADD FOREIGN KEY (property_id)
    REFERENCES public.properties (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;


ALTER TABLE IF EXISTS public.wills
    ADD FOREIGN KEY (person_id)
    REFERENCES public.people (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
    NOT VALID;